# Use Builder mode

`startVerificationFromUrl` and `startVerificationFromJson` use Builder mode
when `api=2` is present. Builder links require a non-empty `sessionId`.
Consumer-owned query parameters, such as redirect parameters, remain part of
the routed link.

Links without `api=2`, or with another value, use the legacy signed-template
flow. A link with `api=2` but no `sessionId` is invalid; the module returns a
verification failure and does not try the legacy parser.

## Configure the module

Before starting a Builder link, configure the module once with an HTTPS Builder
base URL and the UUID of the registered Verification Client. The module sends
that UUID as `x-reclaim-vc-id` on direct Builder requests. This UUID is a public
routing identifier, not an authentication credential. It is distinct from the
per-installation `claimantClientId`. The module reuses the SDK's persistent
legacy device identity for this value; it does not generate a new UUID for
each Builder session.

```dart
final sdk = ReclaimInAppSdk();

await sdk.configureBuilderVerification(
  baseUrl: 'https://build.reclaimprotocol.org',
  verificationClientId: '01234567-89ab-4def-8123-456789abcdef',
);

final response = await sdk.startVerificationFromUrl(context, builderLink);
if (response.exception != null) {
  // Show the host app's verification error state.
  return;
}
```

`configureBuilderVerification` is the Dart convenience API. The equivalent
Builder override is available to Dart, Android, and iOS hosts through the
generated add-to-app API:

```dart
await sdk.setBuilderModeOverrides(
  ClientBuilderModeOverrides(
    baseUrl: 'https://build.reclaimprotocol.org',
    verificationClientId: '01234567-89ab-4def-8123-456789abcdef',
  ),
);
```

```kotlin
val builderOverrides = ClientBuilderModeOverrides(
  baseUrl = "https://build.reclaimprotocol.org",
  verificationClientId = "01234567-89ab-4def-8123-456789abcdef",
)

reclaimModuleApi.setBuilderModeOverrides(builderOverrides) { result ->
  result.getOrThrow()
}
```

```swift
let builderOverrides = ClientBuilderModeOverrides(
  baseUrl: "https://build.reclaimprotocol.org",
  verificationClientId: "01234567-89ab-4def-8123-456789abcdef"
)

reclaimModuleApi.setBuilderModeOverrides(overrides: builderOverrides) { result in
  try? result.get()
}
```

Configure this once before opening an `api=2` link. Calling
`clearAllOverrides` also removes this Builder configuration. A later Builder
link then fails as unconfigured; it does not fall back to legacy mode.

The Builder override configures transport only. Builder bootstrap data remains
authoritative for the session ID, provider recipes, organization and
application branding, attestor authorization, lifecycle events, and result
submission. Existing feature and logging overrides continue to affect the
shared mobile proof engine. Legacy provider, application-info, and session
overrides continue to apply only to legacy links.

Builder bootstrap supplies remote-capable feature flags as an immutable
`runtimeConfig` snapshot. The SDK doesn't call the legacy feature-flag API in
Builder mode. Explicit `ClientFeatureOverrides` still take precedence.

| Override | Builder mode | Legacy mode |
| --- | --- | --- |
| `ClientBuilderModeOverrides` | Configures the Builder URL and Verification Client ID | Ignored |
| `ClientFeatureOverrides` | Applies to supported shared proof-engine behavior | Applies |
| `ClientLogConsumerOverride` | Applies | Applies |
| `ClientProviderInformationOverride` | Ignored; the resolved Builder recipe is authoritative | Applies |
| `ClientReclaimSessionManagementOverride` | Ignored; Builder owns its session lifecycle | Applies |
| `ClientReclaimAppInfoOverride` | Ignored; Builder bootstrap branding and theme are authoritative | Applies |

The module loads bootstrap data and ordered recipes, patches claimant details,
reports lifecycle events, runs the existing proof engine, and submits raw
proofs from that engine to Builder. Builder signs, encrypts, and delivers the
result.

Do not embed a Verification Client signing secret or callback-encryption key
in the host app. If transport, recipe, proof, or result submission fails, the
module returns a verification failure and does not retry as a legacy request.

## Recipe compatibility

The SDK adapter preserves `GET`, `POST`, `PUT`, `PATCH`, and `DELETE`, static
request headers, request bodies, geolocation, provider scripts, and provider-
or request-specific TLS client options. It rejects unknown HTTP methods,
malformed option objects, and AI recipes.
`allowedJsRequests` is not evaluated in the verification client; Consumers
enforce proof requirements with `verifyProof`.
