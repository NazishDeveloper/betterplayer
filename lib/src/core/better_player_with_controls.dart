import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:better_player/better_player.dart';
import 'package:better_player/src/configuration/better_player_controller_event.dart';
import 'package:better_player/src/controls/better_player_cupertino_controls.dart';
import 'package:better_player/src/controls/better_player_material_controls.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/subtitles/better_player_subtitles_drawer.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:flutter/material.dart';

import 'package:vector_math/vector_math_64.dart' show Vector3;

class BetterPlayerWithControls extends StatefulWidget {
  final BetterPlayerController? controller;

   BetterPlayerWithControls({Key? key, this.controller}) : super(key: key);
   late _BetterPlayerWithControlsState betterPlayerWithControlsState;
  @override
  _BetterPlayerWithControlsState createState() =>
      betterPlayerWithControlsState = _BetterPlayerWithControlsState();
}

class _BetterPlayerWithControlsState extends State<BetterPlayerWithControls> {
  BetterPlayerSubtitlesConfiguration get subtitlesConfiguration =>
      widget.controller!.betterPlayerConfiguration.subtitlesConfiguration;

  BetterPlayerControlsConfiguration get controlsConfiguration =>
      widget.controller!.betterPlayerControlsConfiguration;

  final StreamController<bool> playerVisibilityStreamController =
      StreamController();

  bool _initialized = false;
  late _BetterPlayerVideoFitWidget betterPlayerVideoFitWidget;
  StreamSubscription? _controllerEventSubscription;

  double scale = 1.0;
  double prevScale = 1.0;

  @override
  void initState() {
    playerVisibilityStreamController.add(true);
    _controllerEventSubscription =
        widget.controller!.controllerEventStream.listen(_onControllerChanged);
    super.initState();
  }

  @override
  void didUpdateWidget(BetterPlayerWithControls oldWidget) {
    if (oldWidget.controller != widget.controller) {
      _controllerEventSubscription?.cancel();
      _controllerEventSubscription =
          widget.controller!.controllerEventStream.listen(_onControllerChanged);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    playerVisibilityStreamController.close();
    _controllerEventSubscription?.cancel();
    super.dispose();
  }

  void _onControllerChanged(BetterPlayerControllerEvent event) {
    setState(() {
      if (!_initialized) {
        _initialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final BetterPlayerController betterPlayerController =
        BetterPlayerController.of(context);

    double? aspectRatio;
    if (betterPlayerController.isFullScreen) {
      if (betterPlayerController.betterPlayerConfiguration
              .autoDetectFullscreenDeviceOrientation ||
          betterPlayerController
              .betterPlayerConfiguration.autoDetectFullscreenAspectRatio) {
        aspectRatio =
            betterPlayerController.videoPlayerController?.value.aspectRatio ??
                1.0;
      } else {
        aspectRatio = betterPlayerController
                .betterPlayerConfiguration.fullScreenAspectRatio ??
            BetterPlayerUtils.calculateAspectRatio(context);
      }
    } else {
      aspectRatio = betterPlayerController.getAspectRatio();
    }

    aspectRatio ??= 16 / 9;
    final innerContainer = Container(
      width: double.infinity,
      color: betterPlayerController
          .betterPlayerConfiguration.controlsConfiguration.backgroundColor,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: _buildPlayerWithControls(betterPlayerController, context),
      ),
    );

    if (betterPlayerController.betterPlayerConfiguration.expandToFill) {
      return Center(child: innerContainer);
    } else {
      return innerContainer;
    }
  }

  Container _buildPlayerWithControls(BetterPlayerController betterPlayerController, BuildContext context) {
    final configuration = betterPlayerController.betterPlayerConfiguration;
    var rotation = configuration.rotation;

    if (!(rotation <= 360 && rotation % 90 == 0)) {
      BetterPlayerUtils.log("Invalid rotation provided. Using rotation = 0");
      rotation = 0;
    }
    if (betterPlayerController.betterPlayerDataSource == null) {
      return Container();
    }
    _initialized = true;

    final bool placeholderOnTop =
        betterPlayerController.betterPlayerConfiguration.placeholderOnTop;
    // ignore: avoid_unnecessary_containers
    return Container(
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          if (placeholderOnTop) _buildPlaceholder(betterPlayerController),
          Transform.rotate(
            angle: rotation * pi / 180,
            child:  GestureDetector(
              onScaleStart: (d){
                prevScale = scale;
                setState(() {});
              },
              onScaleUpdate: (d){
                scale = prevScale * d.scale;
                setState(() {});
              },
              onScaleEnd: (d){
                prevScale = 1.0;
                setState(() {});
              },
              child: betterPlayerVideoFitWidget = _BetterPlayerVideoFitWidget(
                betterPlayerController,
                betterPlayerController.getFit(),
              ),
            ),
          ),
          betterPlayerController.betterPlayerConfiguration.overlay ??
              Container(),
          BetterPlayerSubtitlesDrawer(
            betterPlayerController: betterPlayerController,
            betterPlayerSubtitlesConfiguration: subtitlesConfiguration,
            subtitles: betterPlayerController.subtitlesLines,
            playerVisibilityStream: playerVisibilityStreamController.stream,
          ),
          if (!placeholderOnTop) _buildPlaceholder(betterPlayerController),
          _buildControls(context, betterPlayerController),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BetterPlayerController betterPlayerController) {
    return betterPlayerController.betterPlayerDataSource!.placeholder ??
        betterPlayerController.betterPlayerConfiguration.placeholder ??
        Container();
  }

  Widget _buildControls(
    BuildContext context,
    BetterPlayerController betterPlayerController,
  ) {
    if (controlsConfiguration.showControls) {
      BetterPlayerTheme? playerTheme = controlsConfiguration.playerTheme;
      if (playerTheme == null) {
        if (Platform.isAndroid) {
          playerTheme = BetterPlayerTheme.material;
        } else {
          playerTheme = BetterPlayerTheme.cupertino;
        }
      }

      if (controlsConfiguration.customControlsBuilder != null &&
          playerTheme == BetterPlayerTheme.custom) {
        return controlsConfiguration.customControlsBuilder!(
            betterPlayerController, onControlsVisibilityChanged);
      } else if (playerTheme == BetterPlayerTheme.material) {
        return _buildMaterialControl();
      } else if (playerTheme == BetterPlayerTheme.cupertino) {
        return _buildCupertinoControl();
      }
    }

    return const SizedBox();
  }

  Widget _buildMaterialControl() {
    return BetterPlayerMaterialControls(
      controlsConfiguration: controlsConfiguration,
      onControlsVisibilityChanged: onControlsVisibilityChanged,
    );
  }

  Widget _buildCupertinoControl() {
    return BetterPlayerCupertinoControls(
      onControlsVisibilityChanged: onControlsVisibilityChanged,
      controlsConfiguration: controlsConfiguration,
    );
  }

  void onControlsVisibilityChanged(bool state) {
    playerVisibilityStreamController.add(state);
  }
}

///Widget used to set the proper box fit of the video. Default fit is 'fill'.
class _BetterPlayerVideoFitWidget extends StatefulWidget {
  _BetterPlayerVideoFitWidget(
    this.betterPlayerController,
    this.boxFit, {
    Key? key,
  }) : super(key: key);
  late _BetterPlayerVideoFitWidgetState betterPlayerVideoFitWidgetState;
  final BetterPlayerController betterPlayerController;
  BoxFit boxFit;

  @override
  _BetterPlayerVideoFitWidgetState createState() => betterPlayerVideoFitWidgetState = _BetterPlayerVideoFitWidgetState();
}

class _BetterPlayerVideoFitWidgetState
    extends State<_BetterPlayerVideoFitWidget> {
  VideoPlayerController? get controller =>
      widget.betterPlayerController.videoPlayerController;


  bool _initialized = false;

  VoidCallback? _initializedListener;

  bool _started = false;

  StreamSubscription? _controllerEventSubscription;

  @override
  void initState() {
    super.initState();
    if (!widget.betterPlayerController.betterPlayerConfiguration
        .showPlaceholderUntilPlay) {
      _started = true;
    } else {
      _started = widget.betterPlayerController.hasCurrentDataSourceStarted;
    }

    _initialize();
  }

  @override
  void didUpdateWidget(_BetterPlayerVideoFitWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.betterPlayerController.videoPlayerController != controller) {
      if (_initializedListener != null) {
        oldWidget.betterPlayerController.videoPlayerController!
            .removeListener(_initializedListener!);
      }
      _initialized = false;
      _initialize();
    }
  }

  void setFit(BoxFit fit){
    setState(() {
      widget.boxFit = fit;
    });
  }

  void _initialize() {
    if (controller?.value.initialized == false) {
      _initializedListener = () {
        if (!mounted) {
          return;
        }

        if (_initialized != controller!.value.initialized) {
          _initialized = controller!.value.initialized;
          setState(() {});
        }
      };
      controller!.addListener(_initializedListener!);
    } else {
      _initialized = true;
    }

    _controllerEventSubscription =
        widget.betterPlayerController.controllerEventStream.listen((event) {
      if (event == BetterPlayerControllerEvent.play) {
        if (!_started) {
          setState(() {
            _started =
                widget.betterPlayerController.hasCurrentDataSourceStarted;
          });
        }
      }
      if (event == BetterPlayerControllerEvent.setupDataSource) {
        setState(() {
          _started = false;
        });
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    if (_initialized && _started) {
      return Center(
        // child: GestureDetector(
        //   onScaleStart: (d){
        //     prevScale = scale;
        //     setState(() {});
        //   },
        //   onScaleUpdate: (d){
        //     scale = prevScale * d.scale;
        //     setState(() {});
        //   },
        //   onScaleEnd: (d){
        //     prevScale = 1.0;
        //     setState(() {});
        //   },
          child: ClipRect(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                fit: widget.boxFit,
                child: SizedBox(
                  width: controller!.value.size?.width ?? 0,
                  height: controller!.value.size?.height ?? 0,
                  // child: Transform(
                  //   alignment: FractionalOffset.center,
                  //     transform: Matrix4.diagonal3(Vector3(scale,scale,scale)),
                      child: VideoPlayer(controller)
                  ),
                ),
              ),
            ),
          // ),
        );
      // );
    } else {
      return const SizedBox();
    }
  }

  @override
  void dispose() {
    if (_initializedListener != null) {
      widget.betterPlayerController.videoPlayerController!
          .removeListener(_initializedListener!);
    }
    _controllerEventSubscription?.cancel();
    super.dispose();
  }
}










































































// import 'dart:async';
// import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
// import 'package:better_player/src/controls/better_player_clickable_widget.dart';
// import 'package:better_player/src/controls/better_player_controls_state.dart';
// import 'package:better_player/src/controls/better_player_material_progress_bar.dart';
// import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
// import 'package:better_player/src/controls/better_player_progress_colors.dart';
// import 'package:better_player/src/core/better_player_controller.dart';
// import 'package:better_player/src/core/better_player_utils.dart';
// import 'package:better_player/src/video_player/video_player.dart';
//
// // Flutter imports:
// import 'package:flutter/material.dart';
// import 'package:nexthour/custom_player/player_imps.dart';
//
// class BetterPlayerMaterialControls extends StatefulWidget {
//   ///Callback used to send information if player bar is hidden or not
//   final Function(bool visbility) onControlsVisibilityChanged;
//
//   ///Controls config
//   final BetterPlayerControlsConfiguration controlsConfiguration;
//
//   const BetterPlayerMaterialControls({
//     Key? key,
//     required this.onControlsVisibilityChanged,
//     required this.controlsConfiguration,
//   }) : super(key: key);
//
//   @override
//   State<StatefulWidget> createState() {
//     return _BetterPlayerMaterialControlsState();
//   }
// }
//
// class _BetterPlayerMaterialControlsState
//     extends BetterPlayerControlsState<BetterPlayerMaterialControls> {
//   VideoPlayerValue? _latestValue;
//   double? _latestVolume;
//   Timer? _hideTimer;
//   Timer? _initTimer;
//   Timer? _showAfterExpandCollapseTimer;
//   bool _displayTapped = false;
//   bool _wasLoading = false;
//   VideoPlayerController? _controller;
//   BetterPlayerController? _betterPlayerController;
//   StreamSubscription? _controlsVisibilityStreamSubscription;
//
//   BetterPlayerControlsConfiguration get _controlsConfiguration =>
//       widget.controlsConfiguration;
//
//   @override
//   VideoPlayerValue? get latestValue => _latestValue;
//
//   @override
//   BetterPlayerController? get betterPlayerController => _betterPlayerController;
//
//   @override
//   BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
//       _controlsConfiguration;
//
//   @override
//   Widget build(BuildContext context) {
//     return buildLTRDirectionality(_buildMainWidget());
//   }
//
//   ///Builds main widget of the controls.
//   Widget _buildMainWidget() {
//     _wasLoading = isLoading(_latestValue);
//     if (_latestValue?.hasError == true) {
//       return Container(
//         color: Colors.black,
//         child: _buildErrorWidget(),
//       );
//     }
//     return GestureDetector(
//       onTap: () {
//         if (BetterPlayerMultipleGestureDetector.of(context) != null) {
//           BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
//         }
//         controlsNotVisible
//             ? cancelAndRestartTimer()
//             : changePlayerControlsNotVisible(true);
//       },
//       onDoubleTap: () {
//         if (BetterPlayerMultipleGestureDetector.of(context) != null) {
//           BetterPlayerMultipleGestureDetector.of(context)!.onDoubleTap?.call();
//         }
//         cancelAndRestartTimer();
//       },
//       onLongPress: () {
//         if (BetterPlayerMultipleGestureDetector.of(context) != null) {
//           BetterPlayerMultipleGestureDetector.of(context)!.onLongPress?.call();
//         }
//       },
//       child: AbsorbPointer(
//         absorbing: controlsNotVisible,
//         child: Stack(
//           fit: StackFit.expand,
//           children: [
//             if (_wasLoading)
//               Center(child: _buildLoadingWidget())
//             else
//               _buildHitArea(),
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: _buildTopBar(),
//             ),
//             Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
//             _buildNextVideoWidget(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _dispose();
//     super.dispose();
//   }
//
//   void _dispose() {
//     _controller?.removeListener(_updateState);
//     _hideTimer?.cancel();
//     _initTimer?.cancel();
//     _showAfterExpandCollapseTimer?.cancel();
//     _controlsVisibilityStreamSubscription?.cancel();
//   }
//
//   @override
//   void didChangeDependencies() {
//     final _oldController = _betterPlayerController;
//     _betterPlayerController = BetterPlayerController.of(context);
//     _controller = _betterPlayerController!.videoPlayerController;
//     _latestValue = _controller!.value;
//
//     if (_oldController != _betterPlayerController) {
//       _dispose();
//       _initialize();
//     }
//
//     super.didChangeDependencies();
//   }
//
//   Widget _buildErrorWidget() {
//     final errorBuilder =
//         _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
//     if (errorBuilder != null) {
//       return errorBuilder(
//           context,
//           _betterPlayerController!
//               .videoPlayerController!.value.errorDescription);
//     } else {
//       final textStyle = TextStyle(color: _controlsConfiguration.textColor);
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.warning,
//               color: _controlsConfiguration.iconsColor,
//               size: 42,
//             ),
//             Text(
//               _betterPlayerController!.translations.generalDefaultError,
//               style: textStyle,
//             ),
//             if (_controlsConfiguration.enableRetry)
//               TextButton(
//                 onPressed: () {
//                   _betterPlayerController!.retryDataSource();
//                 },
//                 child: Text(
//                   _betterPlayerController!.translations.generalRetry,
//                   style: textStyle.copyWith(fontWeight: FontWeight.bold),
//                 ),
//               )
//           ],
//         ),
//       );
//     }
//   }
//
//   Widget _buildTopBar() {
//     if (!betterPlayerController!.controlsEnabled) {
//       return const SizedBox();
//     }
//
//     return Container(
//       child: (_controlsConfiguration.enableOverflowMenu)
//           ? AnimatedOpacity(
//         opacity: controlsNotVisible ? 0.0 : 1.0,
//         duration: _controlsConfiguration.controlsHideTime,
//         onEnd: _onPlayerHide,
//         child: Container(
//           height: _controlsConfiguration.controlBarHeight,
//           width: double.infinity,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               if (_controlsConfiguration.enablePip)
//                 _buildPipButtonWrapperWidget(
//                     controlsNotVisible, _onPlayerHide)
//               else
//                 const SizedBox(),
//               GestureDetector(
//                 child: Icon(Icons.arrow_back),
//                 onTap: (){
//                   Navigator.pop(context);
//                 },
//               ),
//               // Spacer(),
//               PlayerHeading(),
//               _buildMoreButton(),
//               // Row(
//               //   children: [
//               //     // GestureDetector(
//               //     //   child: Icon(Icons.zoom_out_map_outlined),
//               //     //   onTap: (){
//               //     //     _betterPlayerController.setOverriddenFit(BoxFit.)
//               //     //   },
//               //     // ),
//               //   ],
//               // ),
//             ],
//           ),
//         ),
//       )
//           : const SizedBox(),
//     );
//   }
//
//   Widget _buildPipButton() {
//     return BetterPlayerMaterialClickableWidget(
//       onTap: () {
//         betterPlayerController!.enablePictureInPicture(
//             betterPlayerController!.betterPlayerGlobalKey!);
//       },
//       child: Padding(
//         padding: const EdgeInsets.all(8),
//         child: Icon(
//           betterPlayerControlsConfiguration.pipMenuIcon,
//           color: betterPlayerControlsConfiguration.iconsColor,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPipButtonWrapperWidget(
//       bool hideStuff, void Function() onPlayerHide) {
//     return FutureBuilder<bool>(
//       future: betterPlayerController!.isPictureInPictureSupported(),
//       builder: (context, snapshot) {
//         final bool isPipSupported = snapshot.data ?? false;
//         if (isPipSupported &&
//             _betterPlayerController!.betterPlayerGlobalKey != null) {
//           return AnimatedOpacity(
//             opacity: hideStuff ? 0.0 : 1.0,
//             duration: betterPlayerControlsConfiguration.controlsHideTime,
//             onEnd: onPlayerHide,
//             child: Container(
//               height: betterPlayerControlsConfiguration.controlBarHeight,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   _buildPipButton(),
//                 ],
//               ),
//             ),
//           );
//         } else {
//           return const SizedBox();
//         }
//       },
//     );
//   }
//
//   Widget _buildMoreButton() {
//     return BetterPlayerMaterialClickableWidget(
//       onTap: () {
//         onShowMoreClicked();
//       },
//       child: Padding(
//         padding: const EdgeInsets.all(8),
//         child: Icon(
//           _controlsConfiguration.overflowMenuIcon,
//           color: _controlsConfiguration.iconsColor,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     if (!betterPlayerController!.controlsEnabled) {
//       return const SizedBox();
//     }
//     return AnimatedOpacity(
//       opacity: controlsNotVisible ? 0.0 : 1.0,
//       duration: _controlsConfiguration.controlsHideTime,
//       onEnd: _onPlayerHide,
//       child: Container(
//         height: _controlsConfiguration.controlBarHeight + 20.0,
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: <Widget>[
//             Expanded(
//               flex: 75,
//               child: Row(
//                 children: [
//                   if (_controlsConfiguration.enablePlayPause)
//                     _buildPlayPause(_controller!)
//                   else
//                     const SizedBox(),
//                   if (_betterPlayerController!.isLiveStream())
//                     _buildLiveWidget()
//                   else
//                     _controlsConfiguration.enableProgressText
//                         ? _buildPosition()
//                         : const SizedBox(),
//                   // const Spacer(),
//                   if (_betterPlayerController!.isLiveStream())
//                     const SizedBox()
//                   else
//                     _controlsConfiguration.enableProgressBar
//                         ? _buildProgressBar()
//                         : const SizedBox(),
//                   if (_controlsConfiguration.enableMute)
//                     _buildMuteButton(_controller)
//                   else
//                     const SizedBox(),
//                   if (_controlsConfiguration.enableFullscreen)
//                     _buildExpandButton()
//                   else
//                     const SizedBox(),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLiveWidget() {
//     return Text(
//       _betterPlayerController!.translations.controlsLive,
//       style: TextStyle(
//           color: _controlsConfiguration.liveTextColor,
//           fontWeight: FontWeight.bold),
//     );
//   }
//
//   Widget _buildExpandButton() {
//     return Padding(
//       padding: EdgeInsets.only(right: 12.0),
//       child: BetterPlayerMaterialClickableWidget(
//         onTap: _onExpandCollapse,
//         child: AnimatedOpacity(
//           opacity: controlsNotVisible ? 0.0 : 1.0,
//           duration: _controlsConfiguration.controlsHideTime,
//           child: Container(
//             height: _controlsConfiguration.controlBarHeight,
//             padding: const EdgeInsets.symmetric(horizontal: 8.0),
//             child: Center(
//               child: Icon(
//                 _betterPlayerController!.isFullScreen
//                     ? _controlsConfiguration.fullscreenDisableIcon
//                     : _controlsConfiguration.fullscreenEnableIcon,
//                 color: _controlsConfiguration.iconsColor,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHitArea() {
//     if (!betterPlayerController!.controlsEnabled) {
//       return const SizedBox();
//     }
//     return Container(
//       child: Center(
//         child: AnimatedOpacity(
//           opacity: controlsNotVisible ? 0.0 : 1.0,
//           duration: _controlsConfiguration.controlsHideTime,
//           child: _buildMiddleRow(),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMiddleRow() {
//     return Container(
//       color: _controlsConfiguration.controlBarColor,
//       width: double.infinity,
//       height: double.infinity,
//       child: _betterPlayerController?.isLiveStream() == true
//           ? const SizedBox()
//           : Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           if (_controlsConfiguration.enableSkips)
//             _buildSkipButton()
//           else
//             const SizedBox(),
//           _buildReplayButton(_controller!),
//           if (_controlsConfiguration.enableSkips)
//             _buildForwardButton()
//           else
//             const SizedBox(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildHitAreaClickableButton(
//       {Widget? icon, required void Function() onClicked}) {
//     return Container(
//       constraints: const BoxConstraints(maxHeight: 80.0, maxWidth: 80.0),
//       child: BetterPlayerMaterialClickableWidget(
//         onTap: onClicked,
//         child: Align(
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.transparent,
//               borderRadius: BorderRadius.circular(48),
//             ),
//             child: Padding(
//               padding: const EdgeInsets.all(8),
//               child: Stack(
//                 children: [icon!],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildSkipButton() {
//     return _buildHitAreaClickableButton(
//       icon: Icon(
//         _controlsConfiguration.skipBackIcon,
//         size: 24,
//         color: _controlsConfiguration.iconsColor,
//       ),
//       onClicked: skipBack,
//     );
//   }
//
//   Widget _buildForwardButton() {
//     return _buildHitAreaClickableButton(
//       icon: Icon(
//         _controlsConfiguration.skipForwardIcon,
//         size: 24,
//         color: _controlsConfiguration.iconsColor,
//       ),
//       onClicked: skipForward,
//     );
//   }
//
//   Widget _buildReplayButton(VideoPlayerController controller) {
//     final bool isFinished = isVideoFinished(_latestValue);
//     return _buildHitAreaClickableButton(
//       icon: isFinished
//           ? Icon(
//         Icons.replay,
//         size: 42,
//         color: _controlsConfiguration.iconsColor,
//       )
//           : Icon(
//         controller.value.isPlaying
//             ? _controlsConfiguration.pauseIcon
//             : _controlsConfiguration.playIcon,
//         size: 62,
//         color: _controlsConfiguration.iconsColor,
//       ),
//       onClicked: () {
//         if (isFinished) {
//           if (_latestValue != null && _latestValue!.isPlaying) {
//             if (_displayTapped) {
//               changePlayerControlsNotVisible(true);
//             } else {
//               cancelAndRestartTimer();
//             }
//           } else {
//             _onPlayPause();
//             changePlayerControlsNotVisible(true);
//           }
//         } else {
//           _onPlayPause();
//         }
//       },
//     );
//   }
//
//   Widget _buildNextVideoWidget() {
//     return StreamBuilder<int?>(
//       stream: _betterPlayerController!.nextVideoTimeStream,
//       builder: (context, snapshot) {
//         final time = snapshot.data;
//         if (time != null && time > 0) {
//           return BetterPlayerMaterialClickableWidget(
//             onTap: () {
//               _betterPlayerController!.playNextVideo();
//             },
//             child: Align(
//               alignment: Alignment.bottomRight,
//               child: Container(
//                 margin: EdgeInsets.only(
//                     bottom: _controlsConfiguration.controlBarHeight + 20,
//                     right: 24),
//                 decoration: BoxDecoration(
//                   color: _controlsConfiguration.controlBarColor,
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(12),
//                   child: Text(
//                     "${_betterPlayerController!.translations.controlsNextVideoIn} $time...",
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         } else {
//           return const SizedBox();
//         }
//       },
//     );
//   }
//
//   Widget _buildMuteButton(
//       VideoPlayerController? controller,
//       ) {
//     return BetterPlayerMaterialClickableWidget(
//       onTap: () {
//         cancelAndRestartTimer();
//         if (_latestValue!.volume == 0) {
//           _betterPlayerController!.setVolume(_latestVolume ?? 0.5);
//         } else {
//           _latestVolume = controller!.value.volume;
//           _betterPlayerController!.setVolume(0.0);
//         }
//       },
//       child: AnimatedOpacity(
//         opacity: controlsNotVisible ? 0.0 : 1.0,
//         duration: _controlsConfiguration.controlsHideTime,
//         child: ClipRect(
//           child: Container(
//             height: _controlsConfiguration.controlBarHeight,
//             padding: const EdgeInsets.symmetric(horizontal: 8),
//             child: Icon(
//               (_latestValue != null && _latestValue!.volume > 0)
//                   ? _controlsConfiguration.muteIcon
//                   : _controlsConfiguration.unMuteIcon,
//               color: _controlsConfiguration.iconsColor,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPlayPause(VideoPlayerController controller) {
//     return BetterPlayerMaterialClickableWidget(
//       key: const Key("better_player_material_controls_play_pause_button"),
//       onTap: _onPlayPause,
//       child: Container(
//         height: double.infinity,
//         margin: const EdgeInsets.symmetric(horizontal: 4),
//         padding: const EdgeInsets.symmetric(horizontal: 12),
//         child: Icon(
//           controller.value.isPlaying
//               ? _controlsConfiguration.pauseIcon
//               : _controlsConfiguration.playIcon,
//           color: _controlsConfiguration.iconsColor,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPosition() {
//     final position =
//     _latestValue != null ? _latestValue!.position : Duration.zero;
//     final duration = _latestValue != null && _latestValue!.duration != null
//         ? _latestValue!.duration!
//         : Duration.zero;
//
//     return Padding(
//       padding: _controlsConfiguration.enablePlayPause
//           ? const EdgeInsets.only(right: 24)
//           : const EdgeInsets.symmetric(horizontal: 22),
//       child: RichText(
//         text: TextSpan(
//             text: BetterPlayerUtils.formatDuration(position),
//             style: TextStyle(
//               fontSize: 10.0,
//               color: _controlsConfiguration.textColor,
//               decoration: TextDecoration.none,
//             ),
//             children: <TextSpan>[
//               TextSpan(
//                 text: ' / ${BetterPlayerUtils.formatDuration(duration)}',
//                 style: TextStyle(
//                   fontSize: 10.0,
//                   color: _controlsConfiguration.textColor,
//                   decoration: TextDecoration.none,
//                 ),
//               )
//             ]),
//       ),
//     );
//   }
//
//   @override
//   void cancelAndRestartTimer() {
//     _hideTimer?.cancel();
//     _startHideTimer();
//
//     changePlayerControlsNotVisible(false);
//     _displayTapped = true;
//   }
//
//   Future<void> _initialize() async {
//     _controller!.addListener(_updateState);
//
//     _updateState();
//
//     if ((_controller!.value.isPlaying) ||
//         _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
//       _startHideTimer();
//     }
//
//     if (_controlsConfiguration.showControlsOnInitialize) {
//       _initTimer = Timer(const Duration(milliseconds: 200), () {
//         changePlayerControlsNotVisible(false);
//       });
//     }
//
//     _controlsVisibilityStreamSubscription =
//         _betterPlayerController!.controlsVisibilityStream.listen((state) {
//           changePlayerControlsNotVisible(!state);
//           if (!controlsNotVisible) {
//             cancelAndRestartTimer();
//           }
//         });
//   }
//
//   void _onExpandCollapse() {
//     changePlayerControlsNotVisible(true);
//     _betterPlayerController!.toggleFullScreen();
//     _showAfterExpandCollapseTimer =
//         Timer(_controlsConfiguration.controlsHideTime, () {
//           setState(() {
//             cancelAndRestartTimer();
//           });
//         });
//   }
//
//   void _onPlayPause() {
//     bool isFinished = false;
//
//     if (_latestValue?.position != null && _latestValue?.duration != null) {
//       isFinished = _latestValue!.position >= _latestValue!.duration!;
//     }
//
//     if (_controller!.value.isPlaying) {
//       changePlayerControlsNotVisible(false);
//       _hideTimer?.cancel();
//       _betterPlayerController!.pause();
//     } else {
//       cancelAndRestartTimer();
//
//       if (!_controller!.value.initialized) {
//       } else {
//         if (isFinished) {
//           _betterPlayerController!.seekTo(const Duration());
//         }
//         _betterPlayerController!.play();
//         _betterPlayerController!.cancelNextVideoTimer();
//       }
//     }
//   }
//
//   void _startHideTimer() {
//     if (_betterPlayerController!.controlsAlwaysVisible) {
//       return;
//     }
//     _hideTimer = Timer(const Duration(milliseconds: 3000), () {
//       changePlayerControlsNotVisible(true);
//     });
//   }
//
//   void _updateState() {
//     if (mounted) {
//       if (!controlsNotVisible ||
//           isVideoFinished(_controller!.value) ||
//           _wasLoading ||
//           isLoading(_controller!.value)) {
//         setState(() {
//           _latestValue = _controller!.value;
//           if (isVideoFinished(_latestValue) &&
//               _betterPlayerController?.isLiveStream() == false) {
//             changePlayerControlsNotVisible(false);
//           }
//         });
//       }
//     }
//   }
//
//   Widget _buildProgressBar() {
//     return Expanded(
//       flex: 40,
//       child: Container(
//         alignment: Alignment.bottomCenter,
//         padding: const EdgeInsets.symmetric(horizontal: 12),
//         child: BetterPlayerMaterialVideoProgressBar(
//           _controller,
//           _betterPlayerController,
//           onDragStart: () {
//             _hideTimer?.cancel();
//           },
//           onDragEnd: () {
//             _startHideTimer();
//           },
//           onTapDown: () {
//             cancelAndRestartTimer();
//           },
//           colors: BetterPlayerProgressColors(
//               playedColor: _controlsConfiguration.progressBarPlayedColor,
//               handleColor: _controlsConfiguration.progressBarHandleColor,
//               bufferedColor: _controlsConfiguration.progressBarBufferedColor,
//               backgroundColor:
//               _controlsConfiguration.progressBarBackgroundColor),
//         ),
//       ),
//     );
//   }
//
//   void _onPlayerHide() {
//     _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
//     widget.onControlsVisibilityChanged(!controlsNotVisible);
//   }
//
//   Widget? _buildLoadingWidget() {
//     if (_controlsConfiguration.loadingWidget != null) {
//       return Container(
//         color: _controlsConfiguration.controlBarColor,
//         child: _controlsConfiguration.loadingWidget,
//       );
//     }
//
//     return CircularProgressIndicator(
//       valueColor:
//       AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
//     );
//   }
// }
