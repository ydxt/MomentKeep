import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moment_keep/core/services/location_service.dart';

/// 地图选择页面，用于选择位置
class MapSelectPage extends StatefulWidget {
  /// 初始位置
  final LatLng? initialLocation;

  const MapSelectPage({super.key, this.initialLocation});

  @override
  State<MapSelectPage> createState() => _MapSelectPageState();
}

class _MapSelectPageState extends State<MapSelectPage> {
  /// 地图控制器
  MapController? _mapController;
  
  /// 当前选中的位置
  LatLng? _selectedLocation;
  
  /// 是否正在加载位置
  bool _isLoading = false;
  
  /// 地图是否加载错误
  bool _mapLoadingError = false;
  
  /// 位置服务
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // 设置初始位置
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
    } else {
      // 默认位置：北京
      _selectedLocation = const LatLng(39.9042, 116.4074);
      // 尝试获取当前位置
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// 获取当前位置
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      Position? position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        final latLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _selectedLocation = latLng;
        });
        _mapController?.move(latLng, 15);
      }
    } catch (e) {
      debugPrint('获取当前位置失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  /// 重新加载地图
  void _reloadMap() {
    setState(() {
      _mapLoadingError = false;
      // 重新加载地图，通过移动地图触发重新加载
      if (_selectedLocation != null) {
        _mapController?.move(_selectedLocation!, _mapController?.camera.zoom ?? 15);
      }
    });
  }

  /// 处理地图点击事件
  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
    });
  }

  /// 返回选中的位置
  void _returnSelectedLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(context, {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'locationName': '自定义位置',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择位置'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _returnSelectedLocation,
            child: const Text('确定'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 地图背景
          Container(
            color: theme.colorScheme.surfaceVariant,
          ),
          
          // 地图
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation!, 
              initialZoom: 15,
              onTap: _onMapTap,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapReady: () {
                // 地图准备就绪，关闭加载状态
                setState(() {
                  _isLoading = false;
                });
              },
            ),
            children: [
              // 基础地图图层 - 使用OpenStreetMap标准图层
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.moment_keep',
                tileProvider: NetworkTileProvider(),
              ),
              // 地名和POI图层 - 使用专门显示地名的图层
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.moment_keep',
                tileProvider: NetworkTileProvider(),
              ),
              // 选中位置标记
              MarkerLayer(
                markers: [
                  if (_selectedLocation != null)
                    Marker(
                      point: _selectedLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
              // 地图网格线，增强可用性
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      LatLng(_selectedLocation!.latitude - 0.01, _selectedLocation!.longitude - 0.01),
                      LatLng(_selectedLocation!.latitude + 0.01, _selectedLocation!.longitude - 0.01),
                      LatLng(_selectedLocation!.latitude + 0.01, _selectedLocation!.longitude + 0.01),
                      LatLng(_selectedLocation!.latitude - 0.01, _selectedLocation!.longitude + 0.01),
                      LatLng(_selectedLocation!.latitude - 0.01, _selectedLocation!.longitude - 0.01),
                    ],
                    strokeWidth: 1,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                ],
              ),
            ],
          ),
          
          // 地图加载状态
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          
          // 底部操作栏
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // 当前位置按钮
                ElevatedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('当前位置'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                // 位置信息
                if (_selectedLocation != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '坐标信息',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '纬度: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onBackground,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '经度: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onBackground,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 地图不可用时的提示
                        Text(
                          '💡 提示：点击地图或使用当前位置按钮设置位置',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
