## 0.9.0

* Add resolvedVersion to fetch providers override
* Updates inapp module dependency to 0.9.0

## 0.8.3

* Updates inapp module dependency to 0.8.3
* Add support for versioned providers
* Update [BREAKING] session init handler
* Updates the UI with a verification review banner in the verification flow
* Remove [BREAKING] `acceptAiProviders`, and `webhookUrl` from ReclaimVerification Request

## 0.7.0

* Updates inapp module dependency to 0.7.0

## 0.6.0

* Update claim creation updates UI
* Bug fixes and performance improvements
* Updates inapp module dependency to 0.6.0

## 0.5.0

* Add devtools ordering preference for params displayed in UI 
* Fix display of different params with same key
* Update [BREAKING] session initialization and logging api
* Collect performance metrics and send it to session logs
* Add provider script environment
* Add claim creation types to reclaim verification options

## 0.4.0

* Add updated version of reclaim verifier sdk to 0.4.0
* Removed `isResponseRedactionRegexEscapingEnabled` from features override
* Updated verification flow UI
* Fixed support for cascading requests (fixed number)
* Add param interpolation for xpath and jsonpath

## 0.3.0

* Add setter for ReclaimVerificationOptions with attestorAuthenticationRequest which can be used in ReclaimVerification.

## 0.2.1

* [BREAKING] Add mandatory azp validation from capability access token
* [BREAKING] Update issuer of capability access token to 'https://dev.reclaimprotocol.org'

## 0.2.0

- Updated breaking changes in the use of the reclaim_flutter_sdk apis
- Added use of capability access token
- Add new way to fetch provider information from the host app
- Add host notifications for session identity updates
