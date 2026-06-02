import 'dart:io';
import 'package:flutter/material.dart';

class IconHelper {
  static bool isMaterialIcon(String iconValue) {
    return int.tryParse(iconValue) != null;
  }

  static bool isImagePath(String iconValue) {
    if (iconValue.startsWith('file://')) return true;
    if (iconValue.startsWith('/')) return true;
    if (RegExp(r'^[A-Za-z]:[/\\]').hasMatch(iconValue)) return true;
    return false;
  }

  static String parseFilePath(String iconValue) {
    if (iconValue.startsWith('file://')) {
      final uriStr = iconValue;
      try {
        final uri = Uri.parse(uriStr);
        if (uri.scheme == 'file') {
          return uri.toFilePath();
        }
      } catch (_) {
      }
      return iconValue.replaceFirst('file://', '');
    }
    return iconValue;
  }

  static String toFileUri(String filePath) {
    try {
      return Uri.file(filePath).toString();
    } catch (_) {
      return 'file://$filePath';
    }
  }

  static Widget buildIconWidget(String iconValue, {double size = 20, Color? color}) {
    if (iconValue.isEmpty) {
      return Icon(Icons.water_drop, color: color, size: size);
    }
    if (isMaterialIcon(iconValue)) {
      return Icon(
        IconData(int.parse(iconValue), fontFamily: 'MaterialIcons'),
        color: color,
        size: size,
      );
    } else if (isImagePath(iconValue)) {
      final filePath = parseFilePath(iconValue);
      final file = File(filePath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.broken_image, color: color, size: size);
            },
          ),
        );
      }
      return Icon(Icons.broken_image, color: color, size: size);
    } else {
      return Text(
        iconValue,
        style: TextStyle(fontSize: size),
      );
    }
  }
}
