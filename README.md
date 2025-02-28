# Reclaim InApp Verifier SDK Module

This is a wrapper for the Reclaim InApp Verifier SDK. It is used to embed the Reclaim InApp Verifier SDK into non-Flutter native mobile apps.
A Flutter Add-to-app Module for the Reclaim InApp Verifier SDK.

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
