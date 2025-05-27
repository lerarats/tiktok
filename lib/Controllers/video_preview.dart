import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;

  const VideoThumbnailWidget({Key? key, required this.videoPath}) : super(key: key);

  @override
  _VideoThumbnailWidgetState createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    final thumbnail = await VideoThumbnail.thumbnailFile(
      video: widget.videoPath,
      imageFormat: ImageFormat.JPEG,
      quality: 50,
    );

    setState(() {
      _thumbnailPath = thumbnail.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _thumbnailPath != null
        ? Image.file(File(_thumbnailPath!), fit: BoxFit.cover)
        : const Center(child: CircularProgressIndicator());
  }
}
