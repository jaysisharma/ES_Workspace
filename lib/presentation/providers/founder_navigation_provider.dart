import 'package:flutter_riverpod/flutter_riverpod.dart';

class FounderNavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final founderNavigationProvider =
    NotifierProvider<FounderNavigationNotifier, int>(() {
      return FounderNavigationNotifier();
    });
