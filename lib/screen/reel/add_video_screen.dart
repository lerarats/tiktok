import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';

class AddVideoScreen extends StatefulWidget {
  @override
  _AddVideoScreenState createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends State<AddVideoScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _videoFile;
  bool _isUploading = false;

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickVideo(source: source);

    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
      });


      _showCaptionDialog();
    }
  }

  Future<void> _showCaptionDialog() async {
    String caption = '';
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Добавить подпись'),
          content: TextField(
            onChanged: (value) {
              caption = value;
            },
            decoration: InputDecoration(
              hintText: 'Введите подпись к видео',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _uploadVideo(_videoFile!, caption);
              },
              child: Text('Загрузить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadVideo(File video, String caption) async {
    try {
      setState(() {
        _isUploading = true;
      });

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("Ошибка: пользователь не авторизован.");
        return;
      }

      final String videoName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String filePath = p.join('uploads', videoName);
      final String? mimeType = lookupMimeType(video.path);

      final videoBytes = await video.readAsBytes();

      // Загружаем видео в Supabase Storage
      await supabase.storage.from('videos').uploadBinary(
        filePath,
        videoBytes,
        fileOptions: FileOptions(contentType: mimeType),
      );

      // Получаем публичный URL загруженного видео
      final publicUrl = supabase.storage.from('videos').getPublicUrl(filePath);
      print("Видео загружено: $publicUrl");

      // Сохраняем данные видео в базу
      await _saveVideoToDatabase(user, publicUrl, caption);

    } catch (e) {
      print("Ошибка загрузки: $e");
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _saveVideoToDatabase(User user, String videoUrl, String caption) async {
    try {
      final supabase = Supabase.instance.client;
      final profile = await supabase.from('user').select('user_name').eq('id', user.id).single();
      final username = profile['user_name'] ?? 'Аноним';

      final response = await supabase.from('videos').insert({
        'uid': user.id.toString(),
        'username': username,
        'videoUrl': videoUrl,
        'caption': caption,
        'created_at': DateTime.now().toIso8601String(),
        'likes': 0,
        'commentCount': 0,
        'shareCount': 0,
      }).select();


    } catch (e) {
      print("Ошибка сохранения в базу: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF272626),
      appBar: AppBar(title: Text("Добавить Видео",style: const TextStyle(color: Colors.white)),backgroundColor: Colors.black,automaticallyImplyLeading: false,),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isUploading
                ? CircularProgressIndicator()
                : Column(
              children: [
                ElevatedButton(
                  onPressed: () => _pickVideo(ImageSource.gallery),
                  child: Text("Выбрать из галереи",style: const TextStyle(color: Colors.black)),
                ),
                ElevatedButton(
                  onPressed: () => _pickVideo(ImageSource.camera),
                  child: Text("Записать видео",style: const TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
