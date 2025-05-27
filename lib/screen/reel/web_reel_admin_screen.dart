import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kurshachtt/screen/reel/login_screen.dart';
import 'package:kurshachtt/screen/reel/reports_screen.dart';
import 'package:kurshachtt/screen/reel/search_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_sreen_other.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';
import 'package:video_player/video_player.dart';
import '../../Controllers/video_service.dart';
import '../../repository/tables/user_table.dart';
import 'admin_comment_screen.dart';
import 'comment_screen.dart';

class WebAdminReelScreen extends StatefulWidget {
  final String currentUserId;


  const WebAdminReelScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _WebAdminReelScreen createState() => _WebAdminReelScreen();
}

class _WebAdminReelScreen extends State<WebAdminReelScreen> {
  late Future<List<Map<String, dynamic>>> _videosFuture;
  late ScrollController _scrollController;
  StreamSubscription? _videoSubscription;
  StreamSubscription? _commentSubscription;
  final TextEditingController _searchController = TextEditingController();
  RxList<CustomUser> searchedUsers = <CustomUser>[].obs;
  RxBool isSearching = false.obs;


  @override
  void initState() {
    super.initState();
    _videosFuture = fetchVideos();
    _scrollController = ScrollController();
    _subscribeToUpdates();
  }

  Future<void> searchUser(String query) async {
    if (query.isEmpty) {
      isSearching.value = false;
      searchedUsers.clear();
      return;
    }

    isSearching.value = true;

    try {
      final response = await Supabase.instance.client
          .from('user')
          .select()
          .ilike('user_name', '%$query%');

      final data = response as List<dynamic>;
      searchedUsers.value = data.map((user) => CustomUser.fromJson(user)).toList();
    } catch (e) {
      print('Ошибка при поиске пользователей: $e');
    }
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
      final response = await Supabase.instance.client
          .from('videos')
          .select('*, user(user_name, profile_image_url)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Ошибка загрузки видео: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _videoSubscription?.cancel();
    _commentSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[700],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Padding(
          padding: const EdgeInsets.only(left: 1100.0),
          child: SizedBox(
            width: 300,
            height: 36,
            child: TextField(
              controller: _searchController,
              onChanged: (query) {
                searchUser(query);
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Поиск...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                contentPadding: const EdgeInsets.only(left: 16, right: 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _videosFuture = fetchVideos();
              });
            },
          ),

          IconButton(
            icon: const Icon(Icons.report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [

          Obx(() {
            if (!isSearching.value || searchedUsers.isEmpty) {
              return const SizedBox.shrink();
            }

            final filteredUsers = searchedUsers.where((user) => user.email != 'admin@gmail.com').toList();

            if (filteredUsers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),

              );
            }

            return Container(
              color: Colors.black.withOpacity(0.95),
              constraints: const BoxConstraints(maxHeight: 100),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: user.profileImageUrl != null
                          ? NetworkImage(user.profileImageUrl!)
                          : const AssetImage('assets/default_avatar.png') as ImageProvider,
                    ),
                    title: Text(user.userName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(user.email ?? '', style: const TextStyle(color: Colors.white70)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(userId: user.id),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          }),



          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _videosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка загрузки видео: ${snapshot.error}'));
                }

                final videos = snapshot.data!;
                if (videos.isEmpty) {
                  return const Center(
                    child: Text(
                      'Нет видео',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  );
                }

                return TikTokStyleFullPageScroller(
                  contentSize: videos.length,
                  builder: (context, index) {
                    final video = videos[index];
                    return VideoItem(
                      key: ValueKey(video['id']), // 👈 добавлено
                      video: video,
                      currentUserId: widget.currentUserId,
                    );

                  },
                );
              },
            ),
          ),

        ],
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Подтверждение'),
          content: const Text('Вы уверены, что хотите удалить это видео?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Нет'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Да'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

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
                ? Center(
              child: AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController),
              ),
            )
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


        Positioned(
          left: MediaQuery.of(context).size.width * 0.391,
          bottom: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "@${user['user_name']}",
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                widget.video['caption'],
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
        ),


        Positioned(
          right: MediaQuery.of(context).size.width * 0.391,
          bottom: 30,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(user['profile_image_url'] ?? ''),
              ),
              const SizedBox(height: 16),
              GestureDetector(

                child: buildSocialButton(Icons.favorite, likeCount.toString(), isLiked),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminCommentScreen(videoId: widget.video['id']!),
                    ),
                  );
                },
                child: buildSocialButton(Icons.comment, widget.video['commentCount'].toString(), false),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _deleteVideo(widget.video['id']),
                child: buildSocialButton(Icons.delete, '', false),
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
          Icon(
            icon,
            size: 35,
            color: isLiked ? Colors.red : Colors.white,
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

