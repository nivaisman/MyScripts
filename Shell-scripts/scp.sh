#!/usr/bin/env bash
# Creator: Nivaisman
# GitHub: https://github.com/nivaisman
# Version 1.4: validated endpoints, independent confirmation, SFTP-only transfers.

error() {
    printf 'Error: %s\n' "$*" >&2
    return 1
}

read_value() {
    # Preserve spaces and backslashes. EOF must never authorize a transfer.
    IFS= read -r -p "$1" "$2" || {
        error 'Input ended before the transfer was confirmed.'
        return 1
    }
}

validate_text() {
    local LC_ALL=C
    [[ -n "$2" && ! "$2" =~ [[:cntrl:]] ]] || {
        error "$1 must be nonempty and contain no control characters."
        return 1
    }
}

check_runtime() {
    case "$(uname -s)" in
        Linux | Darwin) ;;
        *)
            error 'Use Linux, macOS, or WSL with its POSIX OpenSSH client.'
            return 1
            ;;
    esac
    command -v scp >/dev/null 2>&1 || {
        error 'OpenSSH scp is required.'
        return 1
    }
}

select_options() {
    local choice
    printf '\nLocal system: 1) Windows through WSL  2) Linux/macOS\n'
    read_value 'Choice: ' choice || return 1
    case "$choice" in
        1 | 2) ;;
        *) error 'Invalid local system choice.'; return 1 ;;
    esac

    printf '\nRemote system: 1) Windows  2) Linux/Unix\n'
    read_value 'Choice: ' choice || return 1
    case "$choice" in
        1) remote_os=Windows ;;
        2) remote_os=Linux ;;
        *) error 'Invalid remote system choice.'; return 1 ;;
    esac

    printf '\nTransfer direction: 1) Download  2) Upload\n'
    read_value 'Choice: ' choice || return 1
    case "$choice" in
        1) direction=Download ;;
        2) direction=Upload ;;
        *) error 'Invalid transfer direction.'; return 1 ;;
    esac
}

collect_paths() {
    printf '\nLocal paths must be absolute POSIX paths, e.g. /home/me/file or /mnt/c/Users/me/file.\n'
    printf 'Do not add surrounding shell quotes. Remote paths must also be absolute.\n'
    if [[ "$remote_os" == Windows ]]; then
        printf 'For remote Windows, use forward slashes, e.g. C:/Users/me/file.txt.\n'
    fi
    case "$direction" in
        Download)
            read_value 'Remote file to download: ' remote_path || return 1
            read_value 'Local destination file or existing directory: ' local_path || return 1
            ;;
        Upload)
            read_value 'Local file to upload: ' local_path || return 1
            read_value 'Remote destination file or directory: ' remote_path || return 1
            ;;
        *) error 'Invalid transfer direction.'; return 1 ;;
    esac
    read_value 'Remote username: ' remote_user || return 1
    read_value 'Remote hostname, IP, or bracketed IPv6 address: ' remote_host || return 1
}

validate_transfer() {
    local parent LC_ALL=C
    validate_text 'Local path' "$local_path" || return 1
    validate_text 'Remote path' "$remote_path" || return 1
    validate_text 'Remote username' "$remote_user" || return 1
    validate_text 'Remote host' "$remote_host" || return 1

    # A leading slash unambiguously identifies a POSIX local operand to scp,
    # even when the filename contains a colon. Never guess at C:/ or host:path.
    [[ "$local_path" == /* ]] || {
        error 'Local path must start with /. Use /mnt/c/... in WSL, not C:/..., a URI, or host:path.'
        return 1
    }
    [[ "$remote_user" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] || {
        error 'Remote username may contain only letters, digits, underscore, dot, and hyphen; it must not start with a hyphen or dot.'
        return 1
    }
    # Simple hostnames/SSH aliases and bracketed IPv6 only. OpenSSH performs
    # address resolution; this allowlist prevents operand/option delimiters.
    if [[ ! "$remote_host" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ &&
          ! "$remote_host" =~ ^\[[0-9a-fA-F]*:[0-9a-fA-F:]*\]$ ]]; then
        error 'Use a simple hostname/IP or bracketed IPv6 address, with no username, port, path, or options.'
        return 1
    fi
    case "$remote_os" in
        Linux)
            [[ "$remote_path" == /* ]] || {
                error 'Remote Linux/Unix paths must start with /.'
                return 1
            }
            ;;
        Windows)
            [[ "$remote_path" == /* || "$remote_path" =~ ^[a-zA-Z]:/ ]] || {
                error 'Remote Windows paths must start with / or a drive letter followed by :/.'
                return 1
            }
            ;;
        *) error 'Invalid remote operating system.'; return 1 ;;
    esac
    # SFTP downloads still expand globs. This wrapper transfers one exact file,
    # and deliberately does not support remote wildcard or backslash syntax.
    case "$remote_path" in
        *'*'* | *'?'* | *'['* | *']'* | *\\*)
            error 'Remote paths must not contain wildcards, brackets, or backslashes; use forward slashes.'
            return 1
            ;;
    esac
    case "$direction" in
        Upload)
            [[ -f "$local_path" && -r "$local_path" ]] || {
                error 'Upload source must be an existing, readable local file.'
                return 1
            }
            ;;
        Download)
            [[ "$remote_path" != */ && "${remote_path##*/}" != . &&
               "${remote_path##*/}" != .. ]] || {
                error 'Download source must name a remote file, not a directory.'
                return 1
            }
            if [[ -d "$local_path" ]]; then
                [[ -w "$local_path" ]] || {
                    error 'Local destination directory is not writable.'
                    return 1
                }
            elif [[ -e "$local_path" || -L "$local_path" ]]; then
                [[ -f "$local_path" && -w "$local_path" ]] || {
                    error 'Existing local destination must be a writable regular file or directory.'
                    return 1
                }
            else
                parent="${local_path%/*}"
                parent="${parent:-/}"
                [[ "$local_path" != */ && -d "$parent" && -w "$parent" ]] || {
                    error 'Local destination parent directory must exist and be writable.'
                    return 1
                }
            fi
            ;;
        *) error 'Invalid transfer direction.'; return 1 ;;
    esac
    remote_info="${remote_user}@${remote_host}"
}

confirm_transfer() {
    printf '\nOperation: %s (SFTP only)\n' "$direction"
    case "$direction" in
        Download)
            printf 'Source (remote): %q\nDestination (local): %q\n' "$remote_info:$remote_path" "$local_path"
            ;;
        Upload)
            printf 'Source (local): %q\nDestination (remote): %q\n' "$local_path" "$remote_info:$remote_path"
            ;;
        *) error 'Invalid transfer direction.'; return 1 ;;
    esac
    printf 'Warning: existing destination files may be overwritten.\n'
    read_value 'Proceed? [y/n]: ' final_answer || return 1
}

begin() {
    # Check consent once; neither case of Y can select a transfer direction.
    case "$final_answer" in
        y | Y) ;;
        n | N) printf 'Transfer cancelled.\n'; return 0 ;;
        *) error 'Confirmation must be y or n.'; return 1 ;;
    esac

    # Recheck inputs at the execution boundary. Never use eval or interpolate
    # untrusted values into shell command strings.
    validate_transfer || return 1
    printf '\nStarting SFTP transfer...\n'
    case "$direction" in
        Download) command scp -s -- "$remote_info:$remote_path" "$local_path" ;;
        Upload) command scp -s -- "$local_path" "$remote_info:$remote_path" ;;
        *) error 'Invalid transfer direction.'; return 1 ;;
    esac
    # scp's exit status is the function's status. No automatic legacy fallback.
}

main() {
    # Local dynamic scope keeps each invocation independent, including in tests.
    local remote_os='' direction='' local_path='' remote_path=''
    local remote_user='' remote_host='' remote_info='' final_answer=''
    printf 'SCP file-transfer helper v1.4 | Nivaisman\n'
    check_runtime || return 1
    select_options || return 1
    collect_paths || return 1
    validate_transfer || return 1
    confirm_transfer || return 1
    begin
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
