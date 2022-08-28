import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../../full_picker.dart';

class Camera extends StatefulWidget {
  final bool videoCamera;
  final bool imageCamera;
  final String firstPartFileName;

  const Camera({Key? key, required this.imageCamera, required this.videoCamera, required this.firstPartFileName})
      : super(key: key);

  @override
  _CameraState createState() {
    return _CameraState();
  }
}

class _CameraState extends State<Camera> with WidgetsBindingObserver {
  Color colorCameraButton = Colors.white;
  List<CameraDescription> cameras = [];
  CameraController? controller;

  bool toggleCameraAndTextVisibility = true;
  bool stopVideoClick = false;
  bool recordVideoClick = false;
  bool firstCamera = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _init() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        cameras = await availableCameras();
        setState(() {});
      } catch (_) {
        Navigator.of(context).pop();
      }
    } on CameraException {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cameras.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            _cameraPreviewWidget(),
            buttons(),
          ],
        ),
      ),
    );
  }

  Widget _cameraPreviewWidget() {
    if (controller == null || !controller!.value.isInitialized) {
      onNewCameraSelected(cameras.firstWhere((description) => description.lensDirection == CameraLensDirection.back));
    }

    double scale;
    try {
      scale = 1 / (controller!.value.aspectRatio * MediaQuery.of(context).size.aspectRatio);
    } catch (e) {
      scale = 1.0;
    }

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topCenter,
      child: CameraPreview(controller!),
    );
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller!.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String? filePath) {
      if (filePath == "") return;
      if (mounted) {
        Navigator.pop(context,
            OutputFile([File(filePath!).readAsBytesSync()], PickerFileType.IMAGE, [widget.firstPartFileName + ".jpg"]));
      }
    });
  }

  Future<void> onVideoRecordButtonPressed() async {
    startVideoRecording().then((value) {
      if (mounted) setState(() {});
    });
  }

  Future<void> onStopButtonPressed() async {
    stopVideoClick = true;
    stopVideoRecording().then((file) {
      if (mounted)
        Navigator.pop(
            context,
            OutputFile(
                [File(file!.path).readAsBytesSync()], PickerFileType.VIDEO, [widget.firstPartFileName + ".mp4"]));
    });
  }

  Future<void> startVideoRecording() async {
    if (!controller!.value.isInitialized) {
      return;
    }

    if (controller!.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return;
    }

    try {
      await controller!.startVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      return null;
    }

    await Future.delayed(Duration(seconds: 1));

    try {
      return controller!.stopVideoRecording();
    } catch (e) {
      Navigator.pop(context);
    }
    return null;
  }

  Future<String?> takePicture() async {
    if (!controller!.value.isInitialized) {
      return "";
    }

    if (controller!.value.isTakingPicture) {
      return "";
    }

    try {
      XFile file = await controller!.takePicture();
      return file.path;
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) {
    if (e.code == "cameraPermission") {
      Navigator.pop(context);
      Navigator.pop(context, 1);

      Fluttertoast.showToast(msg: language.deny_access_permission, toastLength: Toast.LENGTH_SHORT);
    }
  }

  buttons() {
    return Container(
      // remove this height
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      alignment: Alignment.centerRight,
      child: Column(
        children: [
          Visibility(
            visible: toggleCameraAndTextVisibility,
            child: Expanded(
              child: SizedBox(
                width: double.infinity,
                child: IconButton(
                    icon: Icon(
                      Icons.flip_camera_android,
                      color: Colors.red,
                      size: 15.w,
                    ),
                    onPressed: () {
                      changeCamera();
                    }),
              ),
            ),
          ),
          const Expanded(
            flex: 5,
            child: SizedBox(
              height: 15,
            ),
          ),
          Visibility(
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            visible: (widget.imageCamera && widget.videoCamera) && toggleCameraAndTextVisibility,
            child: Text(language.tap_for_photo_hold_for_video,
                style: TextStyle(color: Color(0xa3ffffff), fontSize: 21.sp)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 15),
            child: SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onLongPress: widget.videoCamera && widget.imageCamera
                    ? () {
                        videoRecord();
                      }
                    : null,
                onTap: () {
                  if (widget.imageCamera) {
                    if (controller!.value.isRecordingVideo) {
                      onStopButtonPressed();
                    } else {
                      onTakePictureButtonPressed();
                    }
                  } else {
                    videoRecord();
                  }
                },
                child: Icon(
                  Icons.camera,
                  color: colorCameraButton,
                  size: 15.w,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  void changeCamera() {
    if (firstCamera) {
      firstCamera = false;
      onNewCameraSelected(cameras.firstWhere((description) => description.lensDirection == CameraLensDirection.front));
    } else {
      onNewCameraSelected(cameras.firstWhere((description) => description.lensDirection == CameraLensDirection.back));
      firstCamera = true;
    }
  }

  void videoRecord() {
    if (stopVideoClick) return;
    setState(() {
      toggleCameraAndTextVisibility = false;
      colorCameraButton = Colors.green;
    });
    if (controller!.value.isRecordingVideo) {
      onStopButtonPressed();
    } else {
      if (recordVideoClick) return;
      recordVideoClick = true;
      onVideoRecordButtonPressed();
    }
  }
}