audit_remote_script() {
  local url=""
  local auto_run="false"
  local keep_files="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-if-ok)
        auto_run="true"
        shift
        ;;
      --keep)
        keep_files="true"
        shift
        ;;
      -h|--help)
        cat <<'EOF'
Usage:
  audit_remote_script [--run-if-ok] [--keep] <url>

Options:
  --run-if-ok   Execute the downloaded script only if Codex returns "VERDICT: OK"
  --keep        Keep temporary files for manual inspection
  -h, --help    Show this help
EOF
        return 0
        ;;
      *)
        if [[ -z "$url" ]]; then
          url="$1"
        else
          echo "Unexpected argument: $1" >&2
          return 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$url" ]]; then
    echo "Error: missing URL" >&2
    echo "Usage: audit_remote_script [--run-if-ok] [--keep] <url>" >&2
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is not installed" >&2
    return 1
  fi

  if ! command -v codex >/dev/null 2>&1; then
    echo "Error: codex CLI is not installed or not in PATH" >&2
    return 1
  fi

  local tmpdir
  tmpdir="$(mktemp -d)" || return 1

  local script_file="$tmpdir/install.sh"
  local prompt_file="$tmpdir/prompt.txt"
  local report_file="$tmpdir/report.txt"

  cleanup() {
    if [[ "$keep_files" != "true" ]]; then
      rm -rf "$tmpdir"
    else
      echo "Kept temporary files in: $tmpdir"
    fi
  }
  trap cleanup EXIT

  echo "Downloading script..."
  if ! curl -fsSL "$url" -o "$script_file"; then
    echo "Error: failed to download script" >&2
    return 1
  fi

  echo
  echo "Downloaded to: $script_file"
  echo "SHA256:"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$script_file"
  else
    shasum -a 256 "$script_file"
  fi
  echo

  cat > "$prompt_file" <<'EOF'
You are auditing a shell installation script for security risk.

Your first line MUST be exactly one of:
VERDICT: OK
VERDICT: REVIEW
VERDICT: BLOCK

Use:
- OK only if the script appears reasonably safe to run as-is
- REVIEW if it is not clearly malicious but needs human review or has meaningful risk
- BLOCK if it appears malicious, deceptive, or unreasonably dangerous

Then provide these sections:

SUMMARY:
A short executive summary.

FINDINGS:
Bullet list grouped by severity: high, medium, low.

SUSPICIOUS_LINES:
Quote exact lines or clearly identify the dangerous fragments.

NOTES:
Mention:
- sudo or privilege escalation
- destructive commands
- PATH/profile modifications
- systemd/cron/launch persistence
- remote downloads and chained execution
- eval/base64/obfuscation
- telemetry or data exfiltration
- root assumptions
- writes outside user directory

SCRIPT:
EOF

  {
    echo
    cat "$script_file"
  } >> "$prompt_file"

  echo "Running Codex audit..."
  echo

  if ! codex exec --ephemeral "$(cat "$prompt_file")" | tee "$report_file"; then
    echo
    echo "Error: Codex audit failed" >&2
    return 1
  fi

  echo
  local verdict
  verdict="$(grep -m1 '^VERDICT:' "$report_file" | sed 's/^VERDICT:[[:space:]]*//')"

  if [[ -z "$verdict" ]]; then
    echo "Warning: could not parse verdict from Codex output" >&2
    echo "Treating result as REVIEW" >&2
    verdict="REVIEW"
  fi

  echo "Parsed verdict: $verdict"
  echo

  case "$verdict" in
    OK)
      if [[ "$auto_run" == "true" ]]; then
        read -r -p "Codex marked it OK. Execute script now? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          echo "Executing script..."
          bash "$script_file"
        else
          echo "Execution cancelled"
        fi
      else
        echo "Audit passed, but auto execution is disabled"
        echo "To allow conditional execution, use: --run-if-ok"
      fi
      ;;
    REVIEW)
      echo "Codex recommends manual review. Script was NOT executed."
      return 2
      ;;
    BLOCK)
      echo "Codex flagged the script as dangerous. Script was NOT executed."
      return 3
      ;;
    *)
      echo "Unknown verdict '$verdict'. Script was NOT executed."
      return 4
      ;;
  esac
}