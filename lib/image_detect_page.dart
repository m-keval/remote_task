import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:math' as math;

import 'package:remote_task/painters/eye_painter.dart';
import 'package:remote_task/painters/mouth_painter.dart';

class ImageProcessPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ImageProcessPage({super.key, required this.cameras});

  @override
  State<ImageProcessPage> createState() => _ImageProcessPageState();
}

class _ImageProcessPageState extends State<ImageProcessPage> {
  late CameraController cameraController;
  bool isRecording = false;
  bool isFlash = false;
  late Future<void> _initializeControllerFuture;
  FlashMode currentFlashMode = FlashMode.auto;
  CameraLensDirection currentCameraType = CameraLensDirection.back;
  XFile? capturedFile;
  List<Face>? _faces;
  bool isLoading = false;
  ui.Image? _image;
  bool isEyeDetect = false, isMouthDetect = false;
  bool multiFace = false;
  bool isDownloading = false;
  final GlobalKey _globalKey = GlobalKey();

  /* Download Image */
  Future<ui.Image> captureScreenshot() async {
    RenderRepaintBoundary boundary =
        _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    return image;
  }

  Future<bool> saveImage(ui.Image image) async {
    setState(() {
      isDownloading = true;
    });
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List? pngBytes = byteData?.buffer.asUint8List();

    // Save the image to the gallery
    dynamic success = await ImageGallerySaver.saveImage(pngBytes!);
    return success['isSuccess'];
  }

  /*Till this line */

  Future<void> _initializeController() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    cameraController = CameraController(
      firstCamera,
      ResolutionPreset.medium,
    );

    await cameraController.initialize();
  }

  void getImageFacedetections() async {
    final faceDetector = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: true,
        enableTracking: true));

    final InputImage inputImage = InputImage.fromFilePath(capturedFile!.path);

    List<Face> face = await faceDetector.processImage(inputImage);

    if (mounted) {
      setState(() {
        _faces = face;
        if (_faces!.length > 1) {
          setState(() {
            multiFace = true;
          });
          Fluttertoast.showToast(
              msg: "2개 이상의 얼굴이 감지되었어요!",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.TOP,
              timeInSecForIosWeb: 1,
              fontSize: 14.0);
        }
        _loadImage(File(capturedFile!.path));
      });
    }
  }

  _loadImage(File file) async {
    final data = await file.readAsBytes();
    await decodeImageFromList(data).then((value) => setState(() {
          _image = value;
          isLoading = false;
        }));
  }

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeController();
  }

  void _toggleCamera() async {
    final cameras = await availableCameras();
    final newCameraType = currentCameraType == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    CameraDescription newCamera;
    if (newCameraType == CameraLensDirection.front) {
      newCamera =
          cameras.firstWhere((camera) => camera.lensDirection == newCameraType);
    } else {
      newCamera =
          cameras.firstWhere((camera) => camera.lensDirection == newCameraType);
    }

    final newController = CameraController(
      newCamera,
      ResolutionPreset.medium,
    );

    await newController.initialize();

    await cameraController.dispose();
    setState(() {
      cameraController = newController;
      currentCameraType = newCameraType;
    });
    _initializeControllerFuture = cameraController.initialize();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Expanded(
              child: FutureBuilder(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Stack(children: [
                      if (capturedFile != null) ...[
                        RepaintBoundary(
                          key: _globalKey,
                          child: Container(
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : (capturedFile == null)
                                    ? const Center(
                                        child: Text('no image selected'))
                                    : FittedBox(
                                        fit: BoxFit.fitWidth,
                                        child: SizedBox(
                                          width: _image?.width.toDouble(),
                                          height: _image?.height.toDouble(),
                                          child: _image != null
                                              ? Stack(
                                                  children: [
                                                    Image.file(File(
                                                        capturedFile!.path)),
                                                    if (isEyeDetect) ...[
                                                      CustomPaint(
                                                        painter: EyePainter(
                                                            _image!, _faces!),
                                                      ),
                                                    ],
                                                    if (isMouthDetect) ...[
                                                      CustomPaint(
                                                        painter: MouthPainter(
                                                            _image!, _faces!),
                                                      )
                                                    ]
                                                  ],
                                                )
                                              : const SizedBox(),
                                        ),
                                      ),
                          ),
                        )
                      ] else ...[
                        CameraPreview(
                          cameraController,
                        ),
                      ],
                      if (capturedFile == null) ...[
                        Positioned(
                          bottom: 0,
                          width: MediaQuery.of(context).size.width,
                          child: CameraControlArea(
                            onCapturePressed: () {
                              cameraController.takePicture().then((value) {
                                setState(() {
                                  capturedFile = value;
                                });
                                getImageFacedetections();
                              });
                            },
                            onTogglePressed: () {
                              _toggleCamera();
                            },
                          ),
                        ),
                      ] else ...[
                        Positioned(
                            bottom: 0,
                            width: MediaQuery.of(context).size.width,
                            child: FaceDetectControl(
                              onCaptureAgain: () {
                                setState(() {
                                  capturedFile = null;
                                  multiFace = false;
                                });
                              },
                              eyeClick: () {
                                setState(() {
                                  isEyeDetect = !isEyeDetect;
                                });
                              },
                              mouthClick: () {
                                setState(() {
                                  isMouthDetect = !isMouthDetect;
                                });
                              },
                              eyeVisible: isEyeDetect,
                              mouthVisible: isMouthDetect,
                              onDownload: () {
                                captureScreenshot().then((value) => {
                                      saveImage(value).then((value) {
                                        setState(() {
                                          isDownloading = false;
                                          capturedFile = null;
                                          isEyeDetect = false;
                                          isMouthDetect = false;
                                        });
                                        Fluttertoast.showToast(
                                            msg: "파일 다운로드 성공",
                                            toastLength: Toast.LENGTH_LONG,
                                            gravity: ToastGravity.TOP,
                                            timeInSecForIosWeb: 1,
                                            fontSize: 14.0);
                                      })
                                    });
                              },
                              isDownloading: isDownloading,
                              multiFace: multiFace,
                            ))
                      ],
                      TopControl(
                          onClearPressed: () {
                            setState(() {
                              capturedFile = null;
                              isEyeDetect = false;
                              isMouthDetect = false;
                            });
                          },
                          onMorePressed: () {})
                    ]);
                  } else {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CaptureButton extends StatelessWidget {
  const CaptureButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 59,
      width: 59,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: Colors.white,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
        margin: const EdgeInsets.all(3.5),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: Colors.black,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class CameraControlArea extends StatelessWidget {
  final VoidCallback onCapturePressed;
  final VoidCallback onTogglePressed;

  const CameraControlArea(
      {super.key,
      required this.onCapturePressed,
      required this.onTogglePressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onCapturePressed,
            child: const CaptureButton(),
          ),
          const SizedBox(
            height: 10,
          ),
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(15.0),
                  onTap: () {},
                  child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: SvgPicture.asset('images/gallery.svg')),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(15.0),
                  onTap: onTogglePressed,
                  child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: SvgPicture.asset('images/switch_camera.svg')),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class TopControl extends StatelessWidget {
  final VoidCallback onClearPressed;
  final VoidCallback onMorePressed;

  const TopControl(
      {super.key, required this.onClearPressed, required this.onMorePressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                onPressed: onClearPressed,
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                )),
            IconButton(
                onPressed: onMorePressed,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                ))
          ],
        ),
      ),
    );
  }
}

class FaceDetectControl extends StatefulWidget {
  final VoidCallback onCaptureAgain;
  final VoidCallback eyeClick;
  final bool eyeVisible;
  final bool mouthVisible;
  final bool multiFace;
  final VoidCallback mouthClick;
  final VoidCallback onDownload;
  final bool isDownloading;

  const FaceDetectControl(
      {super.key,
      required this.onCaptureAgain,
      required this.eyeClick,
      required this.multiFace,
      required this.mouthClick,
      required this.eyeVisible,
      required this.mouthVisible,
      required this.onDownload,
      required this.isDownloading});

  @override
  State<FaceDetectControl> createState() => _FaceDetectControlState();
}

class _FaceDetectControlState extends State<FaceDetectControl> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.32,
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: widget.onCaptureAgain,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 10,
                    ),
                    SvgPicture.asset(
                      'images/back.svg',
                      width: 20,
                      height: 20,
                    ),
                    const Text(
                      " 다시찍기",
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.multiFace == false) ...[
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: widget.eyeClick,
                      child: Container(
                        height: 55,
                        width: 55,
                        decoration: BoxDecoration(
                            color: widget.eyeVisible
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10)),
                        child: Center(
                            child: Text(
                          "눈",
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 18,
                              color: widget.eyeVisible
                                  ? Colors.black
                                  : Colors.white),
                        )),
                      ),
                    ),
                    const SizedBox(width: 15),
                    InkWell(
                      onTap: widget.mouthClick,
                      child: Container(
                        height: 55,
                        width: 55,
                        decoration: BoxDecoration(
                            color: widget.mouthVisible
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10)),
                        child: Center(
                            child: Text(
                          "눈",
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 18,
                              color: widget.mouthVisible
                                  ? Colors.black
                                  : Colors.white),
                        )),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 45,
                child: ElevatedButton(
                    style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.disabled)) {
                            return Colors.grey; // Color when button is disabled
                          }
                          return const Color(
                              0xFF7B8FF7); // Color when button is enabled
                        }),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12.0)))),
                    onPressed:
                        widget.eyeVisible == true && widget.mouthVisible == true
                            ? widget.onDownload
                            : null,
                    child: widget.isDownloading == true
                        ? const CircularProgressIndicator()
                        : const Text(
                            "저장하기",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
