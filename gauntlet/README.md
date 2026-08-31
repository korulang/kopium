# Gauntlets — external-oracle campaigns against KOPIUM

KOPIUM-facing gauntlets live here. Each subdirectory is one campaign: ledger,
verdict, and any cross-language closer tooling. Regression **pins** stay in
`/Users/larsde/src/koru` (`tests/regression/…`) because they exercise
`koru_std` — the compiler repo owns the suite, kopium owns the campaign story.

## Campaigns

| path | oracle | koru pins |
|---|---|---|
| [`cordis/`](cordis/) | [cordiverse/cordis](https://github.com/cordiverse/cordis) | `400_RUNTIME_FEATURES/440_RESOURCE_BRIDGE/440_010`–`440_016` |

```bash
# Cross-language closer (requires cordis-ref clone + koru on disk)
cd /Users/larsde/src/kopium
node gauntlet/cordis/crosslang/closer.mjs
node gauntlet/cordis/crosslang/falsify.mjs
```
