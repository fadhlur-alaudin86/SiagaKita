import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CustomCameraView extends StatefulWidget {
  final Function(XFile) onPictureTaken;
  final String title;
  final CameraLensDirection lensDirection;
  final bool isOvalOverlay;
  final bool showOverlay;
  final bool allowFlip; // Izinkan toggle depan/belakang

  const CustomCameraView({
    super.key,
    required this.onPictureTaken,
    this.title = 'Ambil Foto',
    this.lensDirection = CameraLensDirection.front,
    this.isOvalOverlay = true,
    this.showOverlay = true,
    this.allowFlip = false,
  });

  @override
  State<CustomCameraView> createState() => _CustomCameraViewState();
}

class _CustomCameraViewState extends State<CustomCameraView> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  late CameraLensDirection _currentDirection;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _currentDirection = widget.lensDirection;
    _initCamera(_currentDirection);
  }

  Future<void> _initCamera(CameraLensDirection direction) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Cari kamera sesuai arah yang diminta (depan/belakang)
      final targetCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == direction,
        orElse: () => _cameras.first,
      );

      final newController = CameraController(
        targetCamera,
        ResolutionPreset.medium, // Resolusi sedang agar tidak boros storage
        enableAudio: false,
      );

      await newController.initialize();
      if (!mounted) return;

      // Dispose controller lama jika ada
      await _controller?.dispose();

      setState(() {
        _controller = newController;
        _currentDirection = direction;
        _isCameraInitialized = true;
        _isSwitching = false;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  Future<void> _flipCamera() async {
    if (_isSwitching || !widget.allowFlip) return;
    setState(() {
      _isCameraInitialized = false;
      _isSwitching = true;
    });
    final newDirection = _currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _initCamera(newDirection);
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final file = await _controller!.takePicture();
      widget.onPictureTaken(file);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        actions: [
          // Tombol flip kamera (tampil jika allowFlip = true dan ada kamera depan & belakang)
          if (widget.allowFlip && _cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: _isSwitching ? null : _flipCamera,
              tooltip: 'Ganti Kamera',
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Instruksi Text
          if (widget.showOverlay)
            Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: Text(
                widget.isOvalOverlay
                    ? 'Posisikan wajah Anda di dalam area oval\ndan pastikan pencahayaan cukup'
                    : 'Posisikan KTP Anda di dalam area kotak\ndan pastikan tulisan terbaca jelas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),

          // Camera Preview (1:1 Aspect Ratio)
          Center(
            child: ClipRect(
              child: SizedBox(
                width: size.width,
                height: size.width,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 1,
                        height: _controller!.value.previewSize?.width ?? 1,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                    // Overlay (Oval untuk wajah)
                    if (widget.showOverlay)
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.6),
                          BlendMode.srcOut,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                backgroundBlendMode: BlendMode.dstOut,
                              ),
                            ),
                            Center(
                              child: Container(
                                width: widget.isOvalOverlay
                                    ? size.width *
                                          0.55 // Oval lebih kecil
                                    : size.width * 0.85, // KTP lebih lebar
                                height: widget.isOvalOverlay
                                    ? size.width *
                                          0.70 // Rasio wajah
                                    : size.width * 0.53, // Rasio KTP (~1.6:1)
                                decoration: BoxDecoration(
                                  color: Colors.white, // Membuat tembus pandang
                                  borderRadius: widget.isOvalOverlay
                                      ? BorderRadius.all(
                                          Radius.elliptical(
                                            size.width * 0.275,
                                            size.width * 0.35,
                                          ),
                                        )
                                      : BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Row tombol: flip + capture
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Tombol Capture (tengah)
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Tombol flip (kanan, hanya jika allowFlip=true)
                if (widget.allowFlip && _cameras.length > 1)
                  Positioned(
                    right: 60,
                    child: GestureDetector(
                      onTap: _isSwitching ? null : _flipCamera,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(color: Colors.white38, width: 1),
                        ),
                        child: Icon(
                          _currentDirection == CameraLensDirection.back
                              ? Icons.camera_front
                              : Icons.camera_rear,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Label kamera aktif
          if (widget.allowFlip && _cameras.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _currentDirection == CameraLensDirection.back
                    ? 'Kamera Belakang'
                    : 'Kamera Depan',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
