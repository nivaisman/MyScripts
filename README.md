# MyScripts Repository

Bash scripts I made during my AWS Re/Start bootcamp studies, individually and
as part of team projects.

## SCP file-transfer helper

[`Shell-scripts/scp.sh`](Shell-scripts/scp.sh) interactively uploads or downloads
one file using OpenSSH's SFTP transport. Version 1.4 validates endpoints,
separates confirmation from transfer direction, and refuses ambiguous paths.

### Requirements

- Bash on Linux, macOS, or Windows through WSL. Automated tests currently run
  on Linux; live macOS, WSL, and remote Windows transfers have not been tested.
- A currently supported, patched OpenSSH client. OpenSSH 9.0+ is the supported
  baseline; the wrapper explicitly uses `scp -s` to select SFTP even if a
  client's default differs. Unsupported clients fail rather than fall back to
  the legacy SCP protocol.
- A remote SSH server with SFTP enabled and an account with the permissions
  needed for the selected transfer.

Native Windows PowerShell/CMD, Git Bash, and Cygwin are not supported local
runtimes for this version. In WSL, use the Linux OpenSSH client and Linux path
syntax, not `scp.exe` or raw Windows drive-letter paths.

### Usage

```bash
bash Shell-scripts/scp.sh
```

Choose the local and remote systems, then Download or Upload. Enter the paths,
remote username, and remote hostname/IP, review both endpoints, and confirm
with `y` or `Y`; `n` or `N` cancels.

- **Local paths:** Absolute POSIX paths only, such as `/home/me/report.txt`
  or `/mnt/c/Users/me/report.txt` in WSL. `C:/...`, relative paths, `~/...`,
  `host:path`, and URIs are rejected rather than guessed or expanded.
- **Remote Linux/Unix paths:** Absolute paths beginning with `/`.
- **Remote Windows paths:** Forward-slash paths such as
  `C:/Users/me/report.txt`, or absolute paths supported by the SFTP server.
  Windows server drive mapping remains server-specific.
- **Spaces and quoting:** Type paths as-is, without adding surrounding shell
  quotes. Spaces are preserved. Newlines separate answers, so pasted multiline
  text can answer subsequent prompts, including confirmation. Do not pipe
  untrusted text or paste multiline input into this interactive wrapper.
- **Remote patterns:** Remote wildcards, brackets, and backslashes are
  deliberately unsupported; the wrapper is not a recursive or globbing tool.
- **Remote users/hosts:** Simple usernames and hostnames/SSH aliases are
  supported. Use bracketed IPv6, for example `[2001:db8::1]`. Domain-qualified
  usernames and inline ports are not supported; configure ports/jump hosts
  through a trusted SSH configuration instead.
- **Overwrites:** Existing destination files may be overwritten after your
  confirmation. This wrapper does not provide atomic replacement, backups,
  symlink isolation, or a no-clobber guarantee.

Uploads require a readable local regular file. Downloads require an existing
writable destination directory or a file in an existing writable parent
directory; remote access permissions are checked by OpenSSH during transfer.
Invalid input, EOF, and SCP failures return a nonzero status.

### Security behavior

The wrapper passes separate quoted arguments, places `--` before file
operands, and explicitly requests SFTP with `-s`. It never uses `eval`, adds
legacy `-O`, or retries in legacy mode. Local paths beginning with `/` cannot
be interpreted as a second SSH endpoint by POSIX OpenSSH.

SSH authentication, host-key verification, and trusted `~/.ssh/config` settings
remain in effect. Verify new host fingerprints independently, avoid running
as root, and do not disable host-key checking to make a transfer work.
Use the wrapper interactively with trusted input; it is not a privilege
boundary for an automated service or an untrusted shared directory.

OpenSSH documents the legacy SCP remote-shell behavior and the switch to SFTP
in its [9.0 release notes](https://www.openssh.com/txt/release-9.0).

## Development checks

Run from the repository root with Python 3.9+ and ShellCheck installed:

```bash
bash -n Shell-scripts/scp.sh
shellcheck --severity=style Shell-scripts/scp.sh
python3 -m unittest discover -s tests -v
```

The regression tests run the complete interactive script with a fake `scp`
executable. They never connect to remote hosts or transfer real files, and
cover confirmation/direction, endpoint validation, EOF, argument preservation,
SFTP-only invocation, and transfer error propagation.

The `Shell checks` GitHub Actions workflow runs these checks with read-only
repository permissions and a commit-pinned checkout action. Enable secret
scanning/push protection in GitHub settings and require the workflow's status
check in branch protection after its first successful run; code changes alone
do not enable those repository-level controls.
