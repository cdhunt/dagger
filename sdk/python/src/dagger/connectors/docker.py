import logging
import os
import platform
import subprocess
import tempfile
import time
from pathlib import Path

import anyio
from attrs import Factory, define, field

from dagger import Client
from dagger.exceptions import DaggerException

from .base import Config, register_connector
from .http import HTTPConnector

logger = logging.getLogger(__name__)


ENGINE_SESSION_BINARY_PREFIX = "dagger-engine-session-"


def get_platform() -> tuple[str, str]:
    normalized_arch = {
        "x86_64": "amd64",
        "aarch64": "arm64",
    }
    uname = platform.uname()
    os_name = uname.system.lower()
    arch = uname.machine.lower()
    arch = normalized_arch.get(arch, arch)
    return os_name, arch


class ImageRef:
    DIGEST_LEN = 16

    def __init__(self, ref: str) -> None:
        self.ref = ref

        # Check to see if ref contains @sha256:, if so use the digest as the id.
        if "@sha256:" not in ref:
            raise ValueError("Image ref must contain a digest")

        id_ = ref.split("@sha256:", maxsplit=1)[1]
        # TODO: add verification that the digest is valid
        # (not something malicious with / or ..)
        self.id = id_[: self.DIGEST_LEN]


@define
class Engine:
    cfg: Config

    _proc: subprocess.Popen | None = field(default=None, init=False)

    def start(self) -> None:
        cache_dir = (
            Path(os.environ.get("XDG_CACHE_HOME", "~/.cache")).expanduser() / "dagger"
        )
        cache_dir.mkdir(mode=0o700, parents=True, exist_ok=True)

        os_, arch = get_platform()

        image = ImageRef(self.cfg.host.hostname + self.cfg.host.path)
        engine_session_bin_path = (
            cache_dir / f"{ENGINE_SESSION_BINARY_PREFIX}{image.id}"
        )
        if os_ == "windows":
            engine_session_bin_path = engine_session_bin_path.with_suffix(".exe")

        if not engine_session_bin_path.exists():
            tempfile_args = {
                "prefix": f"temp-{ENGINE_SESSION_BINARY_PREFIX}",
                "dir": cache_dir,
                "delete": False,
            }
            with tempfile.NamedTemporaryFile(**tempfile_args) as tmp_bin:

                def cleanup():
                    """Remove the tmp_bin on error."""
                    tmp_bin.close()
                    os.unlink(tmp_bin.name)

                docker_run_args = [
                    "docker",
                    "run",
                    "--rm",
                    "--entrypoint",
                    "/bin/cat",
                    image.ref,
                    f"/usr/bin/{ENGINE_SESSION_BINARY_PREFIX}{os_}-{arch}",
                ]
                try:
                    subprocess.run(
                        docker_run_args,
                        stdout=tmp_bin,
                        stderr=subprocess.PIPE,
                        encoding="utf-8",
                        check=True,
                    )
                except FileNotFoundError as e:
                    raise ProvisionError(
                        f"Command '{docker_run_args[0]}' not found."
                    ) from e
                except subprocess.CalledProcessError as e:
                    raise ProvisionError(
                        f"Failed to copy engine session binary: {e.stderr}"
                    ) from e
                else:
                    # Flake8 Ignores
                    # F811 -- redefinition of (yet) unused function
                    # E731 -- assigning a lambda.
                    cleanup = lambda: None  # noqa: F811,E731
                finally:
                    cleanup()

                tmp_bin_path = Path(tmp_bin.name)
                tmp_bin_path.chmod(0o700)

                engine_session_bin_path = tmp_bin_path.rename(engine_session_bin_path)

            # garbage collection of old engine_session binaries
            for bin in cache_dir.glob(f"{ENGINE_SESSION_BINARY_PREFIX}*"):
                if bin != engine_session_bin_path:
                    bin.unlink()

        remote = f"docker-image://{image.ref}"

        engine_session_args = [engine_session_bin_path, "--remote", remote]
        if self.cfg.workdir:
            engine_session_args.extend(
                ["--workdir", str(Path(self.cfg.workdir).absolute())]
            )
        if self.cfg.config_path:
            engine_session_args.extend(
                ["--project", str(Path(self.cfg.config_path).absolute())]
            )

        # Retry starting if "text file busy" error is hit. That error can happen
        # due to a flaw in how Linux works: if any fork of this process happens
        # while the temp binary file is open for writing, a child process can
        # still have it open for writing before it calls exec.
        # See this golang issue (which itself links to bug reports in other
        # langs and the kernel): https://github.com/golang/go/issues/22315
        # Unfortunately, this sort of retry loop is the best workaround. The
        # case is obscure enough that it should not be hit very often at all.
        for _ in range(10):
            try:
                self._proc = subprocess.Popen(
                    engine_session_args,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=self.cfg.log_output or subprocess.PIPE,
                    encoding="utf-8",
                )
            except OSError as e:
                # 26 is ETXTBSY
                if e.errno == 26:
                    time.sleep(0.1)
                else:
                    raise ProvisionError(f"Failed to start engine session: {e}") from e
            except Exception as e:
                raise ProvisionError(f"Failed to start engine session: {e}") from e
            else:
                break
        else:
            raise ProvisionError("Failed to start engine session after retries.")

        try:
            # read port number from first line of stdout
            port = int(self._proc.stdout.readline())
        except ValueError as e:
            # Check if the subprocess exited with an error.
            if not self._proc.poll():
                raise e

            # FIXME: Duplicate writes into a buffer until end of provisioning
            # instead of reading directly from what the user may set in `log_output`
            if self._proc.stderr is not None and self._proc.stderr.readable():
                raise ProvisionError(
                    f"Dagger engine failed to start: {self._proc.stderr.readline()}"
                ) from e

            raise ProvisionError(
                "Dagger engine failed to start, is docker running?"
            ) from e

        # TODO: verify port number is valid
        self.cfg.host = f"http://localhost:{port}"

    def is_running(self) -> bool:
        return self._proc is not None

    def stop(self, exc_type) -> None:
        if not self.is_running():
            return
        self._proc.__exit__(exc_type, None, None)

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, exc_type, *args, **kwargs):
        self.stop(exc_type)


@register_connector("docker-image")
@define
class DockerConnector(HTTPConnector):
    """Provision dagger engine from an image with docker"""

    engine: Engine = Factory(lambda self: Engine(self.cfg), takes_self=True)

    @property
    def query_url(self) -> str:
        return f"{self.cfg.host.geturl()}/query"

    async def connect(self) -> Client:
        # FIXME: Create proper async provisioning later.
        # This is just to support sync faster.
        await anyio.to_thread.run_sync(self.provision_sync)
        return await super().connect()

    async def close(self, exc_type) -> None:
        # FIXME: need exit stack?
        await super().close(exc_type)
        if self.engine.is_running():
            await anyio.to_thread.run_sync(self.engine.stop, exc_type)

    def connect_sync(self) -> Client:
        self.provision_sync()
        return super().connect_sync()

    def provision_sync(self) -> None:
        # FIXME: handle cancellation, retries and timeout
        # FIXME: handle errors during provisioning
        self.engine.start()

    def close_sync(self, exc_type) -> None:
        # FIXME: need exit stack?
        super().close_sync(exc_type)
        self.engine.stop(exc_type)


class ProvisionError(DaggerException):
    """Error while provisioning the Dagger engine."""
