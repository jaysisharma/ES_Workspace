import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinanceNavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final financeNavigationProvider =
    NotifierProvider<FinanceNavigationNotifier, int>(() {
      return FinanceNavigationNotifier();
    });
