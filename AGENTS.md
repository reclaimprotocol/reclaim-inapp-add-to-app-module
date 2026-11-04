# Working in the add-to-app module

This repository exposes the Reclaim InApp SDK to Flutter, Android, and iOS
hosts. Follow the SDK's public API and the module's existing conventions.

## Documentation

- Keep `docs/builder-mode.md` accurate for the current flow: `api=2` selects
  Builder, `x-reclaim-vc-id` identifies the registered Verification Client for
  routing (it is public and does not authenticate the caller),
  clients submit raw proofs to Builder, and Builder signs and encrypts results.
- Use short, task-oriented headings and active voice. Keep terminology and code
  examples consistent across Dart, Kotlin, and Swift.
- Document every new public Dart class, method, and field with a concise dartdoc
  comment. Explain required configuration and failure behavior.

## Generated interfaces

- `pigeon/schema.dart` is the source of truth for the Dart, Kotlin, and Swift
  platform interface. Do not edit generated files under `lib/src/pigeon/` or
  `generated/` by hand.
- After changing the schema, run `make generate`; inspect the generated diff and
  keep the generated files in sync.

## Validation

Run focused checks after changes:

```sh
dart format .
dart analyze
flutter test
```

Never commit or push changes from an agent. Preserve unrelated user work and
mention unresolved validation failures in the handoff.
