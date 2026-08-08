#!/usr/bin/env python3
"""Report SSH status for each Herdr space as a `$ssh` sidebar token.

Polls the Herdr socket API, looks for `ssh` in each pane's foreground
processes, and reports the remote hostname on the owning workspace so
`[ui.sidebar.spaces]` can render it as `$ssh`.

Tokens carry a TTL, so if this daemon dies the badges expire on their own.
"""

import ipaddress
import json
import os
import socket
import sys
import time

SOURCE = "ssh-status"
TOKEN = "ssh"
POLL_SECONDS = 3.0
TTL_MS = 30000
# Unchanged values are re-sent only this often, to keep the TTL alive without
# marking the sidebar dirty on every poll.
REFRESH_SECONDS = 10.0
PREFIX = "ssh:"
MAX_HOSTS = 2

SOCKET_PATH = os.environ.get(
    "HERDR_SOCKET_PATH",
    os.path.expanduser("~/.config/herdr/herdr.sock"),
)

# ssh flags that consume the following argv entry.
FLAGS_WITH_VALUE = set("BbcDEeFIiJLlmOoPpQRSWw")


class Herdr:
    """One short-lived connection per poll; survives server restarts."""

    def __init__(self, path):
        self.path = path
        self.seq = 0

    def call(self, method, params):
        self.seq += 1
        request = {"id": f"{SOURCE}:{self.seq}", "method": method, "params": params}
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.settimeout(2.0)
        try:
            client.connect(self.path)
            client.sendall((json.dumps(request) + "\n").encode())
            buf = b""
            while b"\n" not in buf:
                chunk = client.recv(65536)
                if not chunk:
                    break
                buf += chunk
        finally:
            client.close()
        if not buf.strip():
            return None
        response = json.loads(buf.split(b"\n", 1)[0].decode())
        return response.get("result")


def ssh_target(argv):
    """Pull the destination out of an ssh argv, skipping flags."""
    args = list(argv[1:])
    while args:
        arg = args.pop(0)
        if arg == "--":
            return args[0] if args else None
        if arg.startswith("-") and len(arg) > 1:
            # Bundled short flags: a value-taking flag consumes the rest of
            # the cluster, or the next argv entry if the cluster ends there.
            for index, letter in enumerate(arg[1:], start=1):
                if letter in FLAGS_WITH_VALUE:
                    if index == len(arg) - 1 and args:
                        args.pop(0)
                    break
            continue
        return arg
    return None


def short_host(target):
    """`redbean@mochi.local` -> `mochi`; IP literals are kept intact."""
    if not target:
        return None
    host = target
    if "://" in host:
        host = host.split("://", 1)[1]
    if "@" in host:
        host = host.rsplit("@", 1)[1]
    if host.startswith("["):  # [::1]:22
        host = host[1:].split("]", 1)[0]
    elif host.count(":") == 1:
        host = host.split(":", 1)[0]
    host = host.strip().rstrip(".")
    if not host:
        return None
    try:
        ipaddress.ip_address(host)
        return host
    except ValueError:
        pass
    return host.split(".", 1)[0] or host


def hosts_for_pane(herdr, pane_id):
    try:
        result = herdr.call("pane.process_info", {"pane_id": pane_id})
    except (OSError, json.JSONDecodeError):
        return []
    info = (result or {}).get("process_info") or {}
    hosts = []
    for process in info.get("foreground_processes") or []:
        name = (process.get("name") or process.get("argv0") or "").rsplit("/", 1)[-1]
        if name not in ("ssh", "mosh", "autossh"):
            continue
        host = short_host(ssh_target(process.get("argv") or []))
        if host and host not in hosts:
            hosts.append(host)
    return hosts


def label(hosts):
    if not hosts:
        return None
    shown = hosts[:MAX_HOSTS]
    extra = len(hosts) - len(shown)
    text = ",".join(shown)
    if extra:
        text += f"+{extra}"
    return PREFIX + text


def poll(herdr, previous):
    result = herdr.call("session.snapshot", {})
    snapshot = (result or {}).get("snapshot") or {}
    workspaces = snapshot.get("workspaces") or []
    if not workspaces:
        return previous

    by_workspace = {ws["workspace_id"]: [] for ws in workspaces}
    for pane in snapshot.get("panes") or []:
        workspace_id = pane.get("workspace_id")
        if workspace_id not in by_workspace:
            continue
        for host in hosts_for_pane(herdr, pane["pane_id"]):
            if host not in by_workspace[workspace_id]:
                by_workspace[workspace_id].append(host)

    now = time.monotonic()
    current = {}
    for workspace_id, hosts in by_workspace.items():
        value = label(hosts)
        was_value, was_sent_at = previous.get(workspace_id, (None, 0.0))
        current[workspace_id] = (value, was_sent_at)
        if value == was_value:
            # Nothing changed: only re-send to keep a live token's TTL alive.
            if value is None or now - was_sent_at < REFRESH_SECONDS:
                continue
        params = {
            "workspace_id": workspace_id,
            "source": SOURCE,
            "tokens": {TOKEN: value},
        }
        if value is not None:
            params["ttl_ms"] = TTL_MS
        herdr.call("workspace.report_metadata", params)
        current[workspace_id] = (value, now)
    return current


def main():
    herdr = Herdr(SOCKET_PATH)
    previous = {}
    while True:
        try:
            previous = poll(herdr, previous)
        except (OSError, json.JSONDecodeError) as error:
            # Server restarting or socket missing: forget state and retry.
            print(f"herdr-ssh-status: {error}", file=sys.stderr, flush=True)
            previous = {}
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
