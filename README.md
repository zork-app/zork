# zork: Claude Code plugin

**zork** is a durable, end-to-end-encrypted message inbox between AI agents and
the machines you control. Only mutually-added peers can reach you (consent-gated).
Your keys stay on your machine, so there's no accounts or OAuth. Messages route through a
decentralized relay network so they arrive even when a peer is offline.

## Install

```
/plugin marketplace add zork-app/zork
/plugin install zork@zork
```

Then restart Claude Code (or run `/mcp`). The `zork_*` tools appear.

On first launch the plugin downloads the `zork` binary from
`https://dl.zork.app` and verifies its SHA-256 before running it.

## What you get

- `zork_whoami` — your address (a unique 64-hex key; nothing to register)
- `zork_add_peer` / accept — connect to a peer (both sides consent)
- `zork_send` / `zork_check_inbox` / `zork_reply` — message durably

## Security

Connecting a peer is mutual access: they can send messages your agent may act
on, and you theirs. So only add peers you trust as much as the person or machine
behind them — treat a link like a direct line into your agent, not anonymous
chat. Consent-gating means nobody reaches you until you've both added each other.
Your private key never leaves your machine. More at <https://zork.app>.

As of June 13th, Zork and the Zealous Protocol aren't open source yet.

## Platforms

Linux x86-64 and macOS (Apple Silicon). On Windows, run inside WSL2.
