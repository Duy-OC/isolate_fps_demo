/// Global constants shared across the app.
class AppConstants {
  const AppConstants._();

  /// 16.67 ms budget per frame at 60 Hz.
  static const double frameBudgetMs = 1000 / 60;

  /// Generated file size options (MB). 40 MB gives a clearly visible freeze.
  static const List<int> sizeOptionsMb = [20, 40, 50];
  static const int defaultSizeMb = 40;

  /// Files larger than this ask for confirmation before benchmarking.
  static const int warnPickedBytes = 100 * 1024 * 1024;

  /// Frames to wait so the UI paints the "running" state before blocking.
  static const int settleFrames = 3;

  /// Measure baseline FPS for this long before the task starts.
  static const int baselineMs = 700;

  /// Wait after the task so the giant frozen frame is recorded.
  static const int tailMs = 500;
}
