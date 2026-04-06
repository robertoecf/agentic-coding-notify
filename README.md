# claude-code-notify

macOS notifications with sound and voice alerts for agent CLIs.

The repository still ships the original **Claude Code plugin**, and now also includes a dedicated **Codex adapter**. They live in one repo, but each environment keeps its own entrypoint and installation flow.

## Adapters

| Adapter | Entry point | Installation model |
|---|---|---|
| Claude Code | `hooks/scripts/notify.sh` | Claude plugin |
| Codex | `adapters/codex/notify.sh` | `~/.codex/config.toml` `notify` command |

## What you get

When the adapter fires, you get:

1. Desktop notification via `terminal-notifier` when available
2. Audio alert with `Basso`
3. Voice announcement with the session label
4. Closing sound with `Submarine`

The spoken label is environment-specific. For Codex, the voice uses `Codex {label}`. For Claude, the existing `Claude Code {label}` behavior is preserved.

## Requirements

- macOS
- `afplay`
- `say`
- `osascript`
- [`terminal-notifier`](https://github.com/julienXX/terminal-notifier)

```bash
brew install terminal-notifier
```

## Claude Code

The Claude adapter stays backward-compatible with the existing plugin layout.

### Install

From a local directory:

```bash
claude plugin install /path/to/claude-code-notify
```

From GitHub:

```bash
claude plugin install github:robertoecf/claude-code-iterm-notify
```

Restart Claude Code after installing or updating. Claude loads hooks at session start.

### Claude hooks

The plugin registers two `Notification` hooks:

- `permission_prompt`
- `idle_prompt`

Both still call `hooks/scripts/notify.sh`. That path is now a shim that delegates to `adapters/claude/notify.sh`, so older setups do not break.

### Claude test

```bash
echo '{"message":"test","title":"Claude Code"}' | bash hooks/scripts/notify.sh
```

## Codex

Codex does not use the Claude plugin system. The supported integration point is the `notify` command in `~/.codex/config.toml`.

### Install script only

Copy the adapter to your Codex bin directory:

```bash
bash adapters/codex/install.sh --install-script ~/.codex/bin/codex-notify.sh
```

### Print the config snippet

```bash
bash adapters/codex/install.sh --print-config ~/.codex/bin/codex-notify.sh
```

Expected output:

```toml
notify = ["/Users/you/.codex/bin/codex-notify.sh"]
```

Then add that line to `~/.codex/config.toml`.

### Codex self-test

Run the adapter in dry-run mode:

```bash
bash adapters/codex/install.sh --self-test ~/.codex/bin/codex-notify.sh
```

Or invoke the repository script directly:

```bash
NOTIFY_TEST_MODE=1 bash adapters/codex/notify.sh \
  '{"type":"agent-turn-complete","cwd":"/tmp/example","last-assistant-message":"READY_FOR_REVIEW: notifier pronto","title":"Codex"}'
```

### What the Codex adapter classifies

Codex `notify` is best-effort and follows Codex's own signals, not Claude's hook model.

The adapter maps the final agent message like this:

- `READY_FOR_REVIEW:` → `Pronto para revisao`
- `INPUT_NEEDED:` → `Input necessario`
- `AUTH_NEEDED:` → `Autorizacao necessaria`
- anything else on `agent-turn-complete` → `Turno concluido`

### Session label strategy

The Codex adapter resolves the label in this order:

1. iTerm2 profile name when `ITERM_SESSION_ID` is available
2. Codex App process ancestry when the script is launched from the macOS app
3. normalized terminal name from `TERM_PROGRAM`
4. basename of the `cwd` in the Codex payload
5. `Codex`

This keeps multiple tabs distinguishable without hardcoding agent names into the voice message.

### Supported Codex environments

The adapter now resolves these environments explicitly:

- `Ghostty` → `Ghostty`
- `iTerm2` → profile name when available, otherwise `iTerm2`
- `Apple_Terminal` → `Terminal.app`
- `vscode` → `VS Code`
- Codex macOS App process tree → `Codex App`

## iTerm2 multi-session setup

If you run multiple Claude or Codex sessions in iTerm2, create named profiles such as `1`, `2`, `api`, or `review`.

When a session needs attention, the voice will use the profile name when it can be resolved. That is the cleanest way to identify parallel sessions.

## Repository layout

```text
.
├── adapters
│   ├── claude
│   │   └── notify.sh
│   └── codex
│       ├── install.sh
│       └── notify.sh
├── hooks
│   ├── hooks.json
│   └── scripts
│       └── notify.sh
└── tests
    └── codex_notify_test.sh
```

## Development

Run the Codex adapter regression test:

```bash
./tests/codex_notify_test.sh
```

## Troubleshooting

### Claude plugin stopped firing

- Restart Claude Code
- Check `~/.claude/settings.json` for invalid configuration
- Test `hooks/scripts/notify.sh` manually

### Codex notifications are generic

- Confirm `notify` in `~/.codex/config.toml` points to the right script
- Confirm the script receives the payload as an argument
- Use `NOTIFY_TEST_MODE=1` to inspect parsed output without sending desktop notifications

### Codex does not expose the same events as Claude

That is expected. Codex `notify` is configured through `config.toml`, and the current documented external notification event is `agent-turn-complete`. This repository keeps adapters separate so each environment can use the signals it actually exposes.

## License

MIT — see [LICENSE](LICENSE).
