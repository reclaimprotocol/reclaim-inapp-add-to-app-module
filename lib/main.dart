import 'package:flutter/material.dart';

import 'reclaim_verifier_module.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ReclaimInAppSdk();

  runApp(ReclaimModuleApp(sdk: api));
}

class ReclaimModuleApp extends StatelessWidget {
  const ReclaimModuleApp({super.key, required this.sdk});

  final ReclaimInAppSdk sdk;

  @override
  Widget build(BuildContext context) {
    sdk.setVerificationContext(context);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Center(child: ClaimTriggerIndicator(color: colorScheme.primary)),
        ),
      ),
    );
  }
}
