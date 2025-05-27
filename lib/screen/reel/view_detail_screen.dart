import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class VideoDetailScreen extends StatefulWidget {
  final String videoUrl;
  final String videoId;
  final String authorId;

  const VideoDetailScreen({
    Key? key,
    required this.videoUrl,
    required this.videoId,
    required this.authorId,
  }) : super(key: key);

  @override
  _VideoDetailScreenState createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late VideoPlayerController _controller;
  int _likes = 0;
  String? _authorName;
  String? _authorAvatar;
  List<Map<String, dynamic>> _comments = [];
  TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });

    _fetchVideoData();
    _fetchComments();
  }

  Future<void> _fetchVideoData() async {
    try {
      final response = await Supabase.instance.client
          .from('videos')
          .select('likes, uid')
          .eq('id', widget.videoId)
          .single();

      setState(() {
        _likes = response['likes'] ?? 0;
      });


      final userResponse = await Supabase.instance.client
          .from('user')
          .select('user_name, profile_image_url')
          .eq('id', widget.authorId)
          .single();

      setState(() {
        _authorName = userResponse['user_name'] ?? 'Автор';
        _authorAvatar = userResponse['profile_image_url'] ?? 'https://via.placeholder.com/150';
        // Default avatar
      });
    } catch (e) {
      print("Ошибка получения данных видео: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ошибка загрузки данных видео'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _fetchComments() async {
    try {
      final response = await Supabase.instance.client
          .from('comments')
          .select('comment_text, created_at, user_id')
          .eq('video_id', widget.videoId)
          .order('created_at', ascending: false);

      setState(() {
        _comments = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("Ошибка загрузки комментариев: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ошибка загрузки комментариев'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _toggleLike() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Для лайка необходимо войти в систему'),
          backgroundColor: Colors.red,
        ));
        return;
      }








      await Supabase.instance.client
          .from('videos')
          .update({'likes': _likes + 1})
          .eq('id', widget.videoId);

      setState(() {
        _likes++;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Видео понравилось!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print("Ошибка добавления лайка: $e");
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Для добавления комментария необходимо войти в систему'),
          backgroundColor: Colors.red,
        ));
        return;
      }


      await Supabase.instance.client.from('comments').insert([
        {
          'video_id': widget.videoId,
          'user_id': user.id,
          'comment_text': commentText,
          'created_at': DateTime.now().toIso8601String(),
        }
      ]);


      _fetchComments();

      _commentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Комментарий добавлен!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print("Ошибка добавления комментария: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ошибка добавления комментария'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black12,
        title: const Text('Просмотр видео'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              _controller.value.isInitialized
                  ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
                  : const CircularProgressIndicator(),


              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.thumb_up),
                    onPressed: _toggleLike,
                  ),
                  Text('$_likes Лайков'),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(_authorAvatar ?? ''),
                    radius: 30,
                  ),
                  const SizedBox(width: 10),
                  Text(_authorName ?? 'Автор'),
                ],
              ),

              const Divider(),


              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Комментарии (${_comments.length})',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];

                  return ListTile(
                    title: Text(comment['comment_text'] ?? 'Без текста'),
                    subtitle: Text('Дата: ${comment['created_at']}'),
                  );
                },
              ),


              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Напишите комментарий...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
