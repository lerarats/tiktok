import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurshachtt/screen/reel/profile_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_sreen_other.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiktoklikescroller/tiktoklikescroller.dart';
import 'package:video_player/video_player.dart';
import '../../Controllers/video_service.dart';
import 'comment_screen.dart';

class RealScreen extends StatefulWidget {
  final String currentUserId;

  const RealScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _RealScreenState createState() => _RealScreenState();
}

class _RealScreenState extends State<RealScreen> {
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
            return Center(child: Text('Ошибка загрузки видео: ${snapshot.error}'));
          }

          final videos = snapshot.data as List<Map<String, dynamic>>;


          if (videos.isEmpty) {
            return const Center(
              child: Text(
                'Нет видео',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                ),
              ),
            );
          }


          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _videosFuture = fetchVideos();
                  });
                },
                child: TikTokStyleFullPageScroller(
                  contentSize: videos.length,
                  builder: (context, index) {
                    final video = videos[index];
                    return VideoItem(
                      video: video,
                      currentUserId: widget.currentUserId,
                    );
                  },
                ),
              ),

              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _videosFuture = fetchVideos();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
  int commentCount = 0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    final likedBy = widget.video['likedby'] ?? [];
    isLiked = likedBy.contains(widget.currentUserId);
    likeCount = widget.video['likes'] ?? 0;
    commentCount = widget.video['commentCount'] ?? 0;
  }


  @override
  void didUpdateWidget(covariant VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.video['id'] != widget.video['id']) {
      _videoPlayerController.pause();
      _videoPlayerController.dispose();
      _initializePlayer();

      final likedBy = widget.video['likedby'] ?? [];
      isLiked = likedBy.contains(widget.currentUserId);
      likeCount = widget.video['likes'] ?? 0;
      commentCount = widget.video['commentCount'] ?? 0;
    }
  }



  void _initializePlayer() {
    _videoPlayerController =
    VideoPlayerController.network(widget.video['videoUrl'])
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.setLooping(true);
      });
  }


  void _toggleLike() async {
    final supabase = Supabase.instance.client;
    final videoId = widget.video['id'];
    final userId = widget.currentUserId;

    final updatedLikedBy = [...(widget.video['likedby'] ?? [])];
    final isCurrentlyLiked = updatedLikedBy.contains(userId);

    setState(() {
      isLiked = !isCurrentlyLiked;
      likeCount += isLiked ? 1 : -1;
    });

    try {
      if (isCurrentlyLiked) {
        updatedLikedBy.remove(userId);
      } else {
        updatedLikedBy.add(userId);
      }

      await supabase.from('videos').update({
        'likedby': updatedLikedBy,
        'likes': updatedLikedBy.length,
      }).eq('id', videoId);


      widget.video['likedby'] = updatedLikedBy;
      widget.video['likes'] = updatedLikedBy.length;
    } catch (e) {
      print('Ошибка при обновлении лайков: $e');
    }
  }


  @override
  void dispose() {
    _videoPlayerController.pause();
    _videoPlayerController.dispose();
    super.dispose();
  }

  void _showReportDialog() {
    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Пожаловаться на видео'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Выберите причину жалобы:"),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedReason,
                    hint: const Text("Выберите причину"),
                    items: [
                      "Спам",
                      "Оскорбительное поведение",
                      "Мошенничество",
                      "Другое"
                    ].map((reason) {
                      return DropdownMenuItem(
                        value: reason,
                        child: Text(reason),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () async {
                    await Supabase.instance.client.from('reports').insert({
                      'reporter_id': widget.currentUserId,
                      'reported_video_id': widget.video['id'],
                      'reason': selectedReason,
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Жалоба отправлена')),
                    );
                  },
                  child: const Text('Отправить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMoreOptions() {
    final isAuthor = widget.currentUserId == widget.video['uid'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Поделиться', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _shareVideo();
              },
            ),

            if (isAuthor)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить видео', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await _confirmDelete();
                  if (confirmed) {
                    await deleteVideo();
                  }
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.red),
                title: const Text('Пожаловаться на видео', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog();
                },
              ),
          ],
        );
      },
    );
  }
  void _shareVideo() {
    final videoUrl = widget.video['videoUrl'];

    Share.share('Смотрите это видео: $videoUrl');
  }
  void _copyVideoLink() {
    final videoLink = widget.video['videoUrl'];


    Clipboard.setData(ClipboardData(text: videoLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }

  Future<void> deleteVideo() async {
    try {
      await Supabase.instance.client
          .from('videos')
          .delete()
          .eq('id', widget.video['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Видео удалено')),
      );
    } catch (e) {
      print('Ошибка при удалении видео: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }
  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удаление видео'),
          content: const Text('Вы уверены, что хотите удалить это видео?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ) ??
        false;
  }


  @override
  Widget build(BuildContext context) {
    final user = widget.video['user'];

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -250) {

          if (widget.video['uid'] == widget.currentUserId) {

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen( uid: widget.currentUserId),
              ),
            );
          } else {

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreenOther(
                  userId: widget.video['uid'],
                ),
              ),
            );
          }
        }
      },

      child: Stack(
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


          Positioned(
            top: 350,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: NetworkImage(user['profile_image_url']),
                ),
                const SizedBox(height: 20),


                IconButton(
                  iconSize: 35,
                  icon: Icon(
                    Icons.favorite,
                    color: isLiked ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleLike,
                ),
                Text(
                  likeCount.toString(),
                  style: const TextStyle(color: Colors.white),
                ),


                IconButton(
                  iconSize: 35,
                  icon: const Icon(Icons.comment, color: Colors.white),
                  onPressed: () async {
                    final updatedCommentCount = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentScreen(
                          videoId: widget.video['id'],
                        ),
                      ),
                    );

                    if (updatedCommentCount != null &&
                        updatedCommentCount is int) {
                      setState(() {
                        commentCount = updatedCommentCount;
                      });
                    }
                  },
                ),

                Text(
                  widget.video['commentCount'].toString(),
                  style: const TextStyle(color: Colors.white),
                ),


                if (widget.currentUserId != widget.video['user_id'])
                  IconButton(
                    iconSize: 35,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: _showMoreOptions,
                  ),
              ],
            ),
          ),


          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "@${user['user_name']}",
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                  ),
                  Text(
                    widget.video['caption'],
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget buildSocialButton(IconData icon, String count,
      [bool isLiked = false, VoidCallback? onTap]) {
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
