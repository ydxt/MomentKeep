// 在 minimal_journal_editor.dart 中替换或升级之前的 CameraCapturePage
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraCapturePage extends StatefulWidget {
  final bool isVideoMode; // 初始模式
  const CameraCapturePage({super.key, this.isVideoMode = false});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isRecording = false;
  late bool _isPhotoMode;

  @override
  void initState() {
    super.initState();
    _isPhotoMode = !widget.isVideoMode;
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: true, // 录像需要音频
    );

    await _controller!.initialize();
    if (mounted) setState(() => _isInitializing = false);
  }

  // 处理拍照或录像逻辑
  Future<void> _handleCapture() async {
    if (_isPhotoMode) {
      // 拍照逻辑
      final image = await _controller!.takePicture();
      Navigator.pop(context, {'type': 'image', 'path': image.path});
    } else {
      // 录像逻辑
      if (_isRecording) {
        final video = await _controller!.stopVideoRecording();
        setState(() => _isRecording = false);
        Navigator.pop(context, {'type': 'video', 'path': video.path});
      } else {
        await _controller!.startVideoRecording();
        setState(() => _isRecording = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _controller == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: CameraPreview(_controller!)),
          
          // 顶部关闭
          Positioned(top: 40, left: 20, child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          )),

          // 模式切换 (照片/视频)
          if (!_isRecording)
            Positioned(bottom: 150, left: 0, right: 0, child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeTab("照片", _isPhotoMode, () => setState(() => _isPhotoMode = true)),
                const SizedBox(width: 30),
                _buildModeTab("视频", !_isPhotoMode, () => setState(() => _isPhotoMode = false)),
              ],
            )),

          // 拍摄按钮
          Positioned(bottom: 50, left: 0, right: 0, child: Center(
            child: GestureDetector(
              onTap: _handleCapture,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4))),
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.white,
                      borderRadius: BorderRadius.circular(_isRecording ? 8 : 30),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildModeTab(String title, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(title, style: TextStyle(color: active ? Colors.yellow : Colors.white, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}