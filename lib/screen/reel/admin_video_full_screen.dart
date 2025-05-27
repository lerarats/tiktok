import 'package:flutter/material.dart';
import 'package:kurshachtt/screen/reel/user_profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'comment_screen.dart';
import 'package:flutter/services.dart';



class AdminVideoFullScreen extends StatefulWidget {
  final String videoId;
  final String videoUrl;


  const AdminVideoFullScreen({
    Key? key,
    required this.videoId,
    required this.videoUrl,
  }) : super(key: key);

  @override
  _AdminVideoFullScreenState createState() => _AdminVideoFullScreenState();
}

class _AdminVideoFullScreenState extends State<AdminVideoFullScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  int likes = 0;
  int commentCount = 0;
  bool _isLoadingStats = true;
  String? videoOwnerId;
  String? videoDescription;
  String? videoOwnerName;
  String? videoOwnerAvatar;
  bool isLiked = false;
  List<dynamic> likedBy = [];
  String? videoOwnerRole;
  String? currentUserId;
  String? currentUserRole;




  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _fetchStats();
    _checkIfLiked();

    currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadCurrentUserRole();
  }
  Future<void> _checkIfLiked() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    final res = await supabase
        .from('likes')
        .select()
        .eq('user_id', userId)
        .eq('video_id', widget.videoId);

    setState(() {
      isLiked = res.isNotEmpty;
    });
  }



  void _initializeVideo() {
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _isPlaying = true;
      });
  }

  Future<void> _loadCurrentUserRole() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    final data = await supabase
        .from('user')
        .select('role')
        .eq('id', userId)
        .single();

    setState(() {
      currentUserRole = data['role'];
    });
  }

  Future<void> _fetchStats() async {
    final supabase = Supabase.instance.client;
    try {
      final videoData = await supabase
          .from('videos')
          .select('likes, commentCount, uid, caption, likedby')
          .eq('id', widget.videoId)
          .single();

      final userData = await supabase
          .from('user')
          .select('user_name, profile_image_url')
          .eq('id', videoData['uid'])
          .single();



      setState(() {
        likes = videoData['likes'] ?? 0;
        commentCount = videoData['commentCount'] ?? 0;
        videoOwnerId = videoData['uid'];
        videoDescription = videoData['caption'];
        likedBy = videoData['likedby'] ?? [];
        isLiked = currentUserId != null && likedBy.contains(currentUserId);
        videoOwnerName = userData['user_name'];
        videoOwnerAvatar = userData['profile_image_url'];
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
      setState(() => _isLoadingStats = false);
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  Future<void> _confirmDeleteVideo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить видео'),
        content: Text('Вы уверены, что хотите удалить это видео?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteVideo();
    }
  }


  Future<void> _deleteVideo() async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('videos')
          .delete()
          .eq('id', widget.videoId);
      Navigator.pop(context);
    } catch (e) {
      print('Ошибка при удалении видео: $e');
    }
  }
  Future<void> _toggleLike() async {
    if (currentUserId == null || currentUserRole == 'admin') return;

    final supabase = Supabase.instance.client;

    setState(() {
      isLiked = !isLiked;
      likes += isLiked ? 1 : -1;
    });

    await supabase.rpc(
      isLiked ? 'increment_likes' : 'decrement_likes',
      params: {'video_id_input': widget.videoId},
    );

    if (isLiked) {
      await supabase
          .from('videos')
          .update({'likedby': likedBy..add(currentUserId)})
          .eq('id', widget.videoId);
    } else {
      likedBy.remove(currentUserId);
      await supabase
          .from('videos')
          .update({'likedby': likedBy})
          .eq('id', widget.videoId);
    }
  }


  void _showMoreOptions() async {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      return;
    }


    final userData = await supabase
        .from('user')
        .select('role')
        .eq('id', currentUserId)
        .single();

    final currentUserRole = userData['role'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentUserRole != 'admin') ...[
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.white),
                  title: const Text('Пожаловаться', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.white),
                  title: const Text('Поделиться', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _shareVideo();
                  },
                ),
              ],
              if (currentUserRole == 'admin') ...[
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.white),
                  title: const Text('Удалить', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteVideo();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }



  void _shareVideo() {
    final videoUrl = widget.videoUrl;

    Share.share('Смотрите это видео: $videoUrl');
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
                      'reporter_id': currentUserId,
                      'reported_video_id': widget.videoId,
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


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_controller.value.isInitialized)
            GestureDetector(
              onTap: _togglePlayPause,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          if (!_isPlaying)
            Center(
              child: Icon(Icons.play_arrow, color: Colors.white70, size: 80),
            ),

          Positioned(
            top: 40,
            left: 20,

            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          if (!_isLoadingStats)
            Positioned(
              right: MediaQuery.of(context).size.width * 0.37,

              bottom: 30,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (videoOwnerAvatar != null)
                    GestureDetector(
                      onTap: () {

                      },
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(videoOwnerAvatar!),
                        radius: 25,
                      ),
                    ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: _toggleLike,
                    child: _buildIconWithCount(
                      iconSize: 35,
                      Icons.favorite,
                      likes,
                      iconColor: isLiked ? Colors.red : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentScreen(videoId: widget.videoId),
                        ),
                      );
                    },
                    child: _buildIconWithCount(Icons.comment, commentCount),
                  ),
                  const SizedBox(height: 16),

                  if (videoOwnerId != Supabase.instance.client.auth.currentUser?.id &&
                      videoOwnerRole != 'admin')
                    GestureDetector(
                      onTap: _showMoreOptions,
                      child: const Icon(Icons.more_vert, color: Colors.white, size: 35),
                    ),
                  if (videoOwnerId == Supabase.instance.client.auth.currentUser?.id)
                    GestureDetector(
                      onTap: _confirmDeleteVideo,
                      child: const Icon(Icons.delete, color: Colors.white, size: 35),
                    ),
                ],
              ),
            )
          else
            const Positioned(
              right: 10,
              bottom: 30,
              child: CircularProgressIndicator(),
            ),
          Positioned(
            left: MediaQuery.of(context).size.width * 0.37,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${videoOwnerName ?? 'Имя пользователя'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),
                Text(
                  videoDescription ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildIconWithCount(IconData icon, int count, {Color iconColor = Colors.white,double iconSize = 35,}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(height: 5),

        Text(count == 0 ? '0' : '$count', style: const TextStyle(color: Colors.white)),
      ],
    );
  }



}
