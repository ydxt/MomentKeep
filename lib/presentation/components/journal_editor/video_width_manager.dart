import 'package:flutter/foundation.dart';

/// Global singleton to manage video widths without triggering document rebuilds
class VideoWidthManager {
  static final VideoWidthManager _instance = VideoWidthManager._internal();
  factory VideoWidthManager() => _instance;
  VideoWidthManager._internal();

  // Map of video path to current width factor
  final Map<String, double> _widths = {};

  /// Get the current width for a video, or null if not set
  double? getWidth(String videoPath) {
    return _widths[videoPath];
  }

  /// Set the width for a video
  void setWidth(String videoPath, double width) {
    _widths[videoPath] = width;
    debugPrint('[VideoWidthManager] Set width for $videoPath: $width');
  }

  /// Clear width for a video (when it's removed from document)
  void clearWidth(String videoPath) {
    _widths.remove(videoPath);
  }

  /// Clear all widths (when closing editor)
  void clearAll() {
    _widths.clear();
  }

  /// Get all current widths (for saving)
  Map<String, double> getAllWidths() {
    return Map.from(_widths);
  }
}
