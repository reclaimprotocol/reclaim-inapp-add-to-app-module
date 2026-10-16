# Reclaim InApp Verifier SDK Module

## Verification link modes

Use Builder mode for links with `api=2`. Builder links also require a non-empty
`sessionId`; otherwise, the module rejects the link instead of using the legacy
flow. Links without `api=2`, or with another value, use the legacy
signed-template flow. See [`docs/builder-mode.md`](docs/builder-mode.md).

Native and Dart hosts configure Builder transport through the generated
`setBuilderModeOverrides` API. This keeps Builder configuration separate from
legacy provider and session overrides. See the Builder-mode guide for Android,
iOS, and Dart examples.

This module wraps the Reclaim InApp Verifier SDK for non-Flutter native mobile
apps. It also provides a Flutter add-to-app module.

## Getting Started

For help getting started with Flutter development, view the online
[documentation](https://flutter.dev/).

For instructions integrating Flutter modules to your existing applications,
see the [add-to-app documentation](https://flutter.dev/to/add-to-app).

## Android

To build the AAR file, run `make android`. Generated AAR files have a size of around 88 MB (Last checked on 2025-01-04). 

### Add the AAR file to your Android project

Consuming the Module
1. Open <host>/app/build.gradle
2. Ensure you have the repositories configured, otherwise add them:

```groovy
      String storageUrl = System.env.FLUTTER_STORAGE_BASE_URL ?: "https://storage.googleapis.com"
      repositories {
        maven {
            url '/path/to/module/android/build/host/outputs/repo'
        }
        maven {
            url "$storageUrl/download.flutter.io"
        }
      }
```

3. Make the host app depend on the Flutter module:

```groovy
    dependencies {
      debugImplementation 'org.reclaimprotocol.reclaim_verifier_module:flutter_debug:1.0'
      profileImplementation 'org.reclaimprotocol.reclaim_verifier_module:flutter_profile:1.0'
      releaseImplementation 'org.reclaimprotocol.reclaim_verifier_module:flutter_release:1.0'
    }
```

4. Add the `profile` build type:

```groovy
    android {
      buildTypes {
        profile {
          initWith debug
        }
      }
    }
```

To learn more, visit https://flutter.dev/to/integrate-android-archive

## iOS

To build the iOS framework, run `make ios`. Generated frameworks have a size of around 937 MB (Last checked on 2025-01-04).

## Troubleshooting

### Cronet errors on Android without Google Play services

On Android devices without Google Play services, you might see the following errors in the Android logs:

- `java.lang.RuntimeException: All available Cronet providers are disabled. A provider should be enabled before it can be used.`
- `Google-Play-Services-Cronet-Provider is unavailable.`

The Reclaim InApp SDK uses Cronet for HTTP requests and, by default, it
loads Cronet from Google Play Services. On a device without Play Services there is no provider to load.

To fix this, bundle Cronet into your app instead by adding the following dependency to your
`build.gradle` dependencies block:

```gradle
dependencies {
    // ... other dependencies (not shown for brevity)
    // Use embedded cronet
    implementation("org.chromium.net:cronet-embedded:143.7445.0")
}
```

Use **143.7445.0 or newer**. Do not downgrade this to a 141.x release: in 141 the
`cronet-embedded`, `cronet-shared`, and `cronet-common` artifacts all declare the same
`org.chromium.net` manifest namespace, which fails the build on AGP 9 (see the next section).
143.7445.0 gives each artifact its own namespace.

### Duplicate namespace 'org.chromium.net' on AGP 9

On AGP 9 you may see `:app:processDebugMainManifest` fail with:

```
Namespace 'org.chromium.net' is used in multiple modules and/or libraries:
org.chromium.net:cronet-api:141.7340.3, org.chromium.net:cronet-shared:141.7340.3.
Please ensure that all modules and libraries have a unique namespace.
```

Cronet 141 split `cronet-shared` out of `cronet-api` but shipped both AARs with the same
`org.chromium.net` manifest namespace. AGP derives a library's namespace from that attribute, so two
libraries end up claiming one namespace and the manifest merger's uniqueness check rejects it.
Cronet fixed this in 143.7445.0.

This module constrains Cronet to 143.7445.0 from version 0.43.0 onward, so upgrading the SDK is the
preferred fix. If you are pinned to an older SDK version, add the same constraint in your app:

```gradle
dependencies {
    constraints {
        implementation("org.chromium.net:cronet-api:143.7445.0")
        implementation("org.chromium.net:cronet-shared:143.7445.0")
    }
}
```

Prefer this over `android.uniquePackageNames=false` in `gradle.properties`. That flag only downgrades
the check to a warning, and AGP 10.0 stops honouring it.
