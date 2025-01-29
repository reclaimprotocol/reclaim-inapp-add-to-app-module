import 'package:flutter/material.dart';

class ReclaimModuleScrollBehaviour extends MaterialScrollBehavior {
  const ReclaimModuleScrollBehaviour();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics());
  }
}
