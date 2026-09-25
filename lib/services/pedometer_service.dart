import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'local_db_service.dart';

class PedometerService {
  // Streams
  static StreamSubscription<StepCount>? _stepCountSubscription;
  static StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  // Current values
  static int _todaySteps = 0;
  static int _stepCountAtMidnight = 0;
  static String _status = 'unknown'; // 'walking' | 'stopped' | 'unknown'

  // Callbacks — set these to update your UI
  static void Function(int steps)? onStepsUpdated;
  static void Function(String status)? onStatusUpdated;

  // ── Request permission ─────────────────────────────────────────────────────
  static Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  // ── Start listening ────────────────────────────────────────────────────────
  static Future<void> startListening({
    void Function(int steps)? stepsCallback,
    void Function(String status)? statusCallback,
  }) async {
    onStepsUpdated  = stepsCallback;
    onStatusUpdated = statusCallback;

    final granted = await requestPermission();
    if (!granted) {
      debugLog('Activity recognition permission denied');
      return;
    }

    // Step count stream — gives total steps since last reboot
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
      cancelOnError: false,
    );

    // Pedestrian status stream — 'walking' or 'stopped'
    _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
      _onPedestrianStatus,
      onError: _onPedestrianStatusError,
      cancelOnError: false,
    );

    debugLog('Pedometer started listening');
  }

  // ── Stop listening ─────────────────────────────────────────────────────────
  static void stopListening() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    _stepCountSubscription = null;
    _pedestrianStatusSubscription = null;
    debugLog('Pedometer stopped');
  }

  // ── Step count handler ─────────────────────────────────────────────────────
  static void _onStepCount(StepCount event) async {
    final totalSinceReboot = event.steps;
    final todayKey = DateTime.now().toString().substring(0, 10); // 'yyyy-MM-dd'

    final db = LocalDbService();

    // Check if we have a baseline for today in SQLite
    final savedBaseline = await db.getPedometerBaseline(todayKey);

    if (savedBaseline != null && savedBaseline > totalSinceReboot) {
      // Baseline is corrupt (e.g. from a device reboot resetting the counter)
      // Reset it to current value
      await db.savePedometerBaseline(todayKey, totalSinceReboot);
      _stepCountAtMidnight = totalSinceReboot;
      _todaySteps = 0;
      onStepsUpdated?.call(0);
      return;
    }

    if (savedBaseline == null) {
      // First reading of the day — save as baseline
      _stepCountAtMidnight = totalSinceReboot;
      await db.savePedometerBaseline(todayKey, totalSinceReboot);
      await db.clearOldBaselines(); // cleanup old entries
      debugLog('New baseline saved to SQLite: $totalSinceReboot for $todayKey');
    } else {
      // Use existing baseline from SQLite
      _stepCountAtMidnight = savedBaseline;
      debugLog('Baseline loaded from SQLite: $savedBaseline for $todayKey');
    }

    _todaySteps = (totalSinceReboot - _stepCountAtMidnight).clamp(0, 999999);
    debugLog('Steps today: $_todaySteps');
    onStepsUpdated?.call(_todaySteps);
  }

  static void _onStepCountError(dynamic error) {
    debugLog('Step count error: $error');
    onStepsUpdated?.call(0);
  }

  // ── Pedestrian status handler ──────────────────────────────────────────────
  static void _onPedestrianStatus(PedestrianStatus event) {
    _status = event.status; // 'walking' or 'stopped'
    debugLog('Status: $_status');
    onStatusUpdated?.call(_status);
  }

  static void _onPedestrianStatusError(dynamic error) {
    debugLog('Pedestrian status error: $error');
    onStatusUpdated?.call('unknown');
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  static int   get todaySteps => _todaySteps;
  static String get status    => _status;

  // Estimate calories burned from steps
  // Formula: steps × 0.04 kcal (average for 70kg person)
  static double get estimatedCaloriesBurned =>
      (_todaySteps * 0.04).roundToDouble();

  // ── Debug logger ───────────────────────────────────────────────────────────
  static void debugLog(String msg) {
    assert(() {
      print('=== PEDOMETER: $msg ===');
      return true;
    }());
  }
}