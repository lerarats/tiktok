import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kurshachtt/screen/reel/login_screen.dart';
import 'package:kurshachtt/screen/reel/reports_screen.dart';
import 'package:kurshachtt/screen/reel/search_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';
import 'package:video_player/video_player.dart';
import '../../Controllers/video_service.dart';
import 'comment_screen.dart';

class AdminReelScreen extends StatefulWidget {
  final String currentUserId;

  const AdminReelScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _AdminReelScreen createState() => _AdminReelScreen();

}

class _AdminReelScreen extends State<AdminReelScreen> {
  late Future<List<Map<String, dynamic>>> _videosFuture;
  StreamSubscription? _videoSubscription;
  StreamSubscription? _commentSubscription;

  @override
  void initState() {
    super.initState();
    _videosFuture = fetchVideos();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    final supabase = Supabase.instance.client;


    _videoSubscription = supabase
        .from('videos')
        .stream(primaryKey: ['id'])
        .listen((event) {
      setState(() {
        _videosFuture = fetchVideos();
      });
    });


    _commentSubscription = supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .listen((event) {
      setState(() {
        _videosFuture = fetchVideos();
      });
    });
  }

  Future<List<Map<String, dynamic>>> fetchVideos() async {
    try {
      final List<Map<String, dynamic>> response = await Supabase.instance.client
          .from('videos')
          .select('*, user(user_name, profile_image_url)')
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      print('Ошибка загрузки видео: $e');
      return [];
    }
  }



  @override
  void dispose() {
    _videoSubscription?.cancel();
    _commentSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _videosFuture,
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки видео'));
          }


          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                'Видео нет',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            );
          }

          final videos = snapshot.data as List<dynamic>;

          if (videos.isEmpty) {
            return const Center(
              child: Text(
                'Нет видео',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            );
          } else {
            return TikTokStyleFullPageScroller(
              contentSize: videos.length,
              builder: (context, index) {
                final video = videos[index] as Map<String, dynamic>;
                return VideoItem(
                  video: video,
                  currentUserId: widget.currentUserId,
                );
              },
            );
          }
        },
      ),

      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [

            IconButton(
              icon: const Icon(Icons.search, color: Colors.red),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchScreen()),
                );
              },
            ),


            IconButton(
              icon: const Icon(Icons.report, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ReportsScreen()),
                );
              },
            ),


            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}



class VideoItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final String currentUserId;

  const VideoItem({Key? key, required this.video, required this.currentUserId})
      : super(key: key);

  @override
  _VideoItemState createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem> {
  late VideoPlayerController _videoPlayerController;
  bool isLiked = false;
  int likeCount = 0;
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();

    List likedBy = widget.video['likedby'] ?? [];
    isLiked = likedBy.contains(widget.currentUserId);
    likeCount = widget.video['likes'] ?? 0;
  }

  void _initializePlayer() {
    _videoPlayerController = VideoPlayerController.network(widget.video['videoUrl'])
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.setLooping(true);
        _videoPlayerController.play();
      });
  }



  Future<void> _deleteVideo(String videoId) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Вы должны войти в систему, чтобы удалить видео!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }


    final isAdmin = await _checkAdminRole(user.id);
    if (isAdmin) {
      try {

        await Supabase.instance.client.from('videos').delete().eq('id', videoId);


        await Supabase.instance.client.from('comments').delete().eq('video_id', videoId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Видео удалено успешно!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления видео: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У вас нет прав для удаления этого видео!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _checkAdminRole(String userId) async {
    final response = await Supabase.instance.client
        .from('user')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    return response?['role'] == 'admin';
  }

  @override
  void dispose() {
    _videoPlayerController.pause();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.video['user'];

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (_videoPlayerController.value.isPlaying) {
                  _videoPlayerController.pause();
                  isPaused = true;
                } else {
                  _videoPlayerController.play();
                  isPaused = false;
                }
              });
            },
            child: _videoPlayerController.value.isInitialized
                ? VideoPlayer(_videoPlayerController)
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
        if (isPaused)
          Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: 100,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("@${user['user_name']}", style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text(widget.video['caption'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                Row(
                  children: [
                    buildSocialButton(Icons.favorite, likeCount.toString(), isLiked),
                    buildSocialButton(
                      Icons.comment,
                      widget.video['commentCount'].toString(),
                      false,
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentScreen(videoId: widget.video['id']!),
                          ),
                        );
                      },
                    ),
                    buildSocialButton(
                      Icons.delete,
                      '',
                      false,
                          () => _deleteVideo(widget.video['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(userId: user['id']),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 25,
                  backgroundImage: NetworkImage(user['profile_image_url'] ?? ''),
                ),
              ),
              const SizedBox(height: 20),
              buildSocialButton(Icons.favorite, likeCount.toString(), isLiked),
              const SizedBox(height: 16),
              buildSocialButton(
                Icons.comment,
                widget.video['commentCount'].toString(),
                false,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommentScreen(videoId: widget.video['id']!),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              buildSocialButton(
                Icons.delete,
                '',
                false,
                    () => _deleteVideo(widget.video['id']),
              ),
            ],
          ),
        ),


      ],
    );
  }

  Widget buildSocialButton(IconData icon, String count, [bool isLiked = false, VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: isLiked ? Colors.red : Colors.white, size: 30),
          Text(count, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

