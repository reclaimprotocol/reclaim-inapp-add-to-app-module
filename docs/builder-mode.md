# Use Builder mode

`startVerificationFromUrl` and `startVerificationFromJson` use Builder mode
when `api=2` is present. Builder links require a non-empty `sessionId`.
Consumer-owned query parameters, such as redirect parameters, remain part of
the routed link.

Links without `api=2`, or with another value, use the legacy signed-template
flow. A link with `api=2` but no `sessionId` is invalid; the module returns a
verification failure and does not try the legacy parser.

## Create the session for the in-app SDK

Create the Builder session from your backend with `verificationClientUrl` set
to the in-app SDK's URL, `https://build.reclaimprotocol.org/share/inapp-sdk`
(`VerificationClient.inAppSdk` in `@reclaimprotocol/client`):

```bash
curl -X POST https://build.reclaimprotocol.org/verifications/sessions \
  -H "authorization: Bearer $RECLAIM_ORG_SECRET" \
  -H "content-type: application/json" \
  -d '{
    "providers": [{ "providerId": "<your-provider-id>" }],
    "context": { "userId": "abc" },
    "verificationClientUrl": "https://build.reclaimprotocol.org/share/inapp-sdk"
  }'
```

Pass the returned `verificationUrl` to `startVerificationFromUrl`. Builder fixes
a session's Verification Client when it creates the session, and the module
identifies itself as the in-app SDK. If you omit `verificationClientUrl`,
Builder selects the Portal instead. A Portal (or any other client's) link then
fails here with `403 x-reclaim-vc-id does not match this session`, whether or
not it was opened elsewhere first.

## Start from JSON

If your backend returns fields instead of a link, call
`startVerificationFromJson` with:

```json
{ "api": "2", "sessionId": "<id from the session-creation response>" }
```

- `sessionId` is the `id` Builder returns when the session is created (the same
  value as the `sessionId` query parameter of `verificationUrl`). The session
  must be created for the in-app SDK, as described above.
- Add `"diag": "1"` only if the session's `verificationUrl` contains `diag=1`.
- `api` may be the string `"2"` or the number `2`. The module reads only
  `api`, `sessionId`, and `diag`, and ignores every other key. The Builder URL
  always comes from the module's configuration, never from the JSON.
- A missing or empty `sessionId` returns a verification failure; it never falls
  back to legacy mode.

```kotlin
reclaimModuleApi.startVerificationFromJson(
  mapOf("api" to "2", "sessionId" to sessionId),
) { result ->
  val response = result.getOrThrow()
}
```

```swift
reclaimModuleApi.startVerificationFromJson(
  template: ["api": "2", "sessionId": sessionId]
) { result in
  let response = try? result.get()
}
```

## Configure the module

Configuration is optional. Without it, the module uses
`https://build.reclaimprotocol.org` and the SDK's in-app Verification Client ID,
`00000000-0000-4000-8000-000000000003`. To use a different Builder service or
a registered Verification Client of your own, configure the module once with an
HTTPS Builder base URL and the UUID of that Verification Client. The module sends
that UUID as `x-reclaim-vc-id` on direct Builder requests. This UUID is a public
routing identifier, not an authentication credential. It is distinct from the
per-installation `claimantClientId`. The module reuses the SDK's persistent
legacy device identity for this value; it does not generate a new UUID for
each Builder session.

```dart
final sdk = ReclaimInAppSdk();

await sdk.setBuilderModeOverrides(
  ClientBuilderModeOverrides(
    baseUrl: 'https://build.reclaimprotocol.org',
    verificationClientId: '01234567-89ab-4def-8123-456789abcdef',
  ),
);

final response = await sdk.startVerificationFromUrl(context, builderLink);
if (response.exception != null) {
  // Show the host app's verification error state.
  return;
}
```

The same override is available to Android and iOS hosts through the generated
add-to-app API:

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

Configure this once before opening an `api=2` link. Explicit configuration
replaces the defaults. Calling `clearAllOverrides` removes it, and later
Builder links use the defaults again; they never fall back to legacy mode.

The Builder override configures transport only. Builder bootstrap data remains
authoritative for the session ID, provider recipes, organization and
application branding, attestor authorization, lifecycle events, and result
submission. Existing feature and logging overrides continue to affect the
shared mobile proof engine. Legacy provider, application-info, and session
overrides continue to apply only to legacy links.

Builder bootstrap supplies the initial `runtimeConfig`. After the SDK knows
the claimant identity, it requests a refreshed configuration for that
claimant. If the refresh fails, it uses the bootstrap configuration. The SDK
doesn't call the legacy feature-flag API in Builder mode. Explicit
`ClientFeatureOverrides` still take precedence.

| Override | Builder mode | Legacy mode |
| --- | --- | --- |
| `ClientBuilderModeOverrides` | Overrides the default Builder URL and Verification Client ID | Ignored |
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
The mobile script runtime does not implement `window.Reclaim.refetch` or
`window.Reclaim.browserRequest`; those methods are available only in the portal.
