import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moment_keep/services/database_service.dart';

class UserPointsNotifier extends Notifier<double> {
  @override
  double build() {
    _loadPoints();
    return 0;
  }

  Future<void> _loadPoints() async {
    try {
      final databaseService = DatabaseService();
      final userId = await databaseService.getCurrentUserId() ?? 'default_user';
      final points = await databaseService.getUserPoints(userId);
      state = points;
    } catch (_) {}
  }

  Future<void> refresh() async {
    await _loadPoints();
  }

  void updatePoints(double newPoints) {
    state = newPoints;
  }
}

final userPointsProvider = NotifierProvider<UserPointsNotifier, double>(() {
  return UserPointsNotifier();
});
