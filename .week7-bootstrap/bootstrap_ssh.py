import getpass
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "vendor"))

import paramiko


def main() -> int:
    password = getpass.getpass("VM password: ")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        "127.0.0.1",
        port=2222,
        username="serveradmin",
        password=password,
        allow_agent=False,
        look_for_keys=False,
        timeout=10,
        auth_timeout=10,
    )
    public_key = (ROOT / "id_ed25519.pub").read_text(encoding="utf-8").strip()
    quoted_key = public_key.replace("'", "'\\''")
    command = (
        "set -eu; mkdir -p ~/.ssh; chmod 700 ~/.ssh; "
        "touch ~/.ssh/authorized_keys; "
        "grep -v 'codex-week7-temporary$' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp || true; "
        f"printf '%s\\n' '{quoted_key}' >> ~/.ssh/authorized_keys.tmp; "
        "mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys; "
        "chmod 600 ~/.ssh/authorized_keys; id"
    )
    _, stdout, stderr = client.exec_command(command, timeout=20)
    output = stdout.read().decode("utf-8", errors="replace").strip()
    error = stderr.read().decode("utf-8", errors="replace").strip()
    status = stdout.channel.recv_exit_status()
    client.close()
    if output:
        print(output)
    if error:
        print(error, file=sys.stderr)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
