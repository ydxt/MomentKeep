import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// 习惯提醒实体类
class HabitReminder extends Equatable {
  /// 唯一标识符
  final String id;

  /// 习惯ID
  final String habitId;

  /// 提醒时间
  final TimeOfDay time;

  /// 是否启用
  final bool isEnabled;

  /// 是否启用地理围栏
  final bool isGeofenceEnabled;

  /// 地理围栏纬度
  final double? latitude;

  /// 地理围栏经度
  final double? longitude;

  /// 地理围栏半径（米）
  final double? radius;

  /// 地理围栏名称
  final String? geofenceName;

  /// 是否启用智能时段推荐
  final bool isSmartTimeEnabled;

  /// 重复日期（周一到周日，true表示该天重复）
  final List<bool> repeatDays;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 构造函数
  const HabitReminder({
    required this.id,
    required this.habitId,
    required this.time,
    required this.isEnabled,
    required this.isGeofenceEnabled,
    this.latitude,
    this.longitude,
    this.radius,
    this.geofenceName,
    required this.isSmartTimeEnabled,
    this.repeatDays = const [true, true, true, true, true, false, false],
    required this.createdAt,
    required this.updatedAt,
  });

  /// 复制方法，用于更新习惯提醒
  HabitReminder copyWith({
    String? id,
    String? habitId,
    TimeOfDay? time,
    bool? isEnabled,
    bool? isGeofenceEnabled,
    double? latitude,
    double? longitude,
    double? radius,
    String? geofenceName,
    bool? isSmartTimeEnabled,
    List<bool>? repeatDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitReminder(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
      isGeofenceEnabled: isGeofenceEnabled ?? this.isGeofenceEnabled,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      geofenceName: geofenceName ?? this.geofenceName,
      isSmartTimeEnabled: isSmartTimeEnabled ?? this.isSmartTimeEnabled,
      repeatDays: repeatDays ?? this.repeatDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        habitId,
        time,
        isEnabled,
        isGeofenceEnabled,
        latitude,
        longitude,
        radius,
        geofenceName,
        isSmartTimeEnabled,
        repeatDays,
        createdAt,
        updatedAt,
      ];
}

/// 智能时段推荐实体类
class SmartTimeRecommendation extends Equatable {
  /// 唯一标识符
  final String id;

  /// 习惯ID
  final String habitId;

  /// 推荐时间
  final TimeOfDay recommendedTime;

  /// 推荐分数（0-100）
  final int score;

  /// 推荐原因
  final String reason;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 构造函数
  const SmartTimeRecommendation({
    required this.id,
    required this.habitId,
    required this.recommendedTime,
    required this.score,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 复制方法，用于更新智能时段推荐
  SmartTimeRecommendation copyWith({
    String? id,
    String? habitId,
    TimeOfDay? recommendedTime,
    int? score,
    String? reason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SmartTimeRecommendation(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      recommendedTime: recommendedTime ?? this.recommendedTime,
      score: score ?? this.score,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        habitId,
        recommendedTime,
        score,
        reason,
        createdAt,
        updatedAt,
      ];
}
