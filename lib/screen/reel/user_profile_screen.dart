import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:kurshachtt/screen/reel/profile_screen.dart';
import 'package:kurshachtt/screen/reel/video_full_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'admin_video_full_screen.dart';
import 'followers_screen.dart';
import 'following_screen.dart';
import 'message_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String? profileImageUrl;
  String? userName;
  List<Map<String, dynamic>> userVideos = [];
  bool isLoading = true;
  bool isFollowing = false;
  int followerCount = 0;
  int likeCount = 0;
  int followingCount = 0;
  String? description;

  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _checkIfFollowing();
    _checkIfAdmin();
  }

  Future<void> _reportUser() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    String? selectedReason;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Пожаловаться на пользователя"),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("Выберите причину"),
                    value: selectedReason,
                    items: [
                      "Спам",
                      "Оскорбительное поведение",
                      "Фейковый аккаунт",
                      "Мошенничество",
                      "Другое"
                    ].map((reason) {
                      return DropdownMenuItem(
                        value: reason,
                        child: Text(reason),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Отмена"),
            ),
            TextButton(
              onPressed: () async {
                if (selectedReason != null) {
                  await Supabase.instance.client.from('reports').insert([
                    {
                      'reporter_id': currentUserId,
                      'reported_user_id': widget.userId,
                      'reason': selectedReason!,
                    }
                  ]);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Жалоба отправлена')),
                  );

                  Navigator.pop(context);
                }
              },
              child: const Text("Отправить"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUser() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId != null) {

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Подтвердите удаление'),
            content: const Text('Вы уверены, что хотите удалить этого пользователя? Это действие необратимо.'),
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
      );


      if (confirmed == true) {
        try {
          final response = await Supabase.instance.client
              .from('user')
              .delete()
              .eq('id', widget.userId);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пользователь удален')),
          );

          Navigator.pop(context);
        } catch (e) {
          print("Ошибка удаления пользователя: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось удалить пользователя')),
          );
        }
      }
    }
  }



  Future<void> _fetchUserData() async {
    try {

      final response = await Supabase.instance.client
          .from('user')
          .select('user_name, profile_image_url, description')
          .eq('id', widget.userId)
          .maybeSingle();

      final videos = await Supabase.instance.client
          .from('videos')
          .select('id, videoUrl, likes')
          .eq('uid', widget.userId);



      final followerResponse = await Supabase.instance.client
          .from('followers')
          .select('follower_id')
          .eq('following_id', widget.userId);


      final followingResponse = await Supabase.instance.client
          .from('followers')
          .select('following_id')
          .eq('follower_id', widget.userId);

      setState(() {
        userName = response?['user_name'] ?? 'Пользователь';
        profileImageUrl = response?['profile_image_url'] ??
            'https://ehdliqszkyprsiurkjwf.supabase.co/storage/v1/object/public/photos/default.png';
        description = response?['description'] ?? 'Описание отсутствует';
        print("Описание в setState: $description");
        userVideos = List<Map<String, dynamic>>.from(videos);
        followerCount = followerResponse.length;
        followingCount = followingResponse.length;


        _fetchTotalLikes(videos);

        isLoading = false;
      });
    } catch (e) {
      print("Ошибка загрузки данных: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchTotalLikes(List<Map<String, dynamic>> videos) async {
    try {

      final totalLikes = videos.fold<int>(0, (sum, video) => sum + (video['likes'] as int));

      setState(() {
        likeCount = totalLikes;
      });
    } catch (e) {
      print("Ошибка подсчёта лайков: $e");
    }
  }

  Future<void> _checkIfFollowing() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {

      final response = await Supabase.instance.client
          .from('followers')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', widget.userId)
          .maybeSingle();

      setState(() {
        isFollowing = response != null;
      });
    }
  }


  Future<void> _checkIfAdmin() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null) {

      final response = await Supabase.instance.client
          .from('user')
          .select('role')
          .eq('id', currentUserId)
          .maybeSingle();

      setState(() {
        isAdmin = response?['role'] == 'admin';
      });
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId != null) {
      if (isFollowing) {

        await Supabase.instance.client.from('followers').delete().eq('follower_id', currentUserId).eq('following_id', widget.userId);
      } else {

        await Supabase.instance.client.from('followers').insert([{
          'follower_id': currentUserId,
          'following_id': widget.userId
        }]);
      }

      setState(() {
        isFollowing = !isFollowing;
        isLoading = true;
      });

      await _fetchUserData();
    }
  }


  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isCurrentUser = widget.userId == currentUserId;

    return Scaffold(
        backgroundColor: Color(0xFF272626),
        appBar: AppBar(
        title: Text(userName ?? 'Профиль',style: const TextStyle(color: Colors.white)),

    backgroundColor: Colors.black,
          centerTitle: true,
    actions: [
    if (!isCurrentUser && !isAdmin)
    IconButton(
    icon: const Icon(Icons.report, color: Colors.red),
    onPressed: _reportUser,
    ),
    ],
    ),
    body: RefreshIndicator(
    onRefresh: _fetchUserData,
    child: isLoading
    ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Column(
    children: [
    const SizedBox(height: 20),
    Stack(
    alignment: Alignment.bottomRight,
    children: [
    ClipOval(
    child: GestureDetector(
    onTap: () {
    if (isCurrentUser) {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) =>
    ProfileScreen(uid: currentUserId!),
    ),
    );
    }
    },
    child: CachedNetworkImage(
    imageUrl: profileImageUrl!,
    height: 100,
    width: 100,
    placeholder: (context, url) =>
    const CircularProgressIndicator(),
    errorWidget: (context, url, error) =>
    const Icon(Icons.error, size: 80),
    ),
    ),
    ),
    ],
    ),

    const SizedBox(height: 15),
    Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Column(
    children: [
    GestureDetector(
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) =>
    FollowingScreen(uid: widget.userId),
    ),
    );
    },
    child: Column(
    children: [
    Text('$followingCount',
    style: const TextStyle(
    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
    const SizedBox(height: 5),
    const Text('Подписки', style: TextStyle(fontSize: 14,color: Colors.white)),
    ],
    ),
    ),
    ],
    ),
    Container(
    color: Colors.black54,
    width: 1,
    height: 15,
    margin: const EdgeInsets.symmetric(horizontal: 15),
    ),
    GestureDetector(
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) =>
    FollowersScreen(uid: widget.userId, isFollowers: false),
    ),
    );
    },
    child: Column(
    children: [
    Text('$followerCount',
    style: const TextStyle(
    fontSize: 20, fontWeight: FontWeight.bold,color: Colors.white)),
    const SizedBox(height: 5),
    const Text('Подписчики', style: TextStyle(fontSize: 14,color: Colors.white)),
    ],
    ),
    ),
    Container(
    color: Colors.black54,
    width: 1,
    height: 15,
    margin: const EdgeInsets.symmetric(horizontal: 15),
    ),
    Column(
    children: [
    Text(
    '$likeCount',
    style: const TextStyle(
    fontSize: 20, fontWeight: FontWeight.bold,color: Colors.white),
    ),
    const SizedBox(height: 5),
    const Text(
    'Лайки',
    style: TextStyle(fontSize: 14,color: Colors.white),
    ),
    ],
    ),
    ],
    ),
    Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Text(
    description ?? 'Описание отсутствует',
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 16, color: Colors.white70),
    ),
    ),

    const SizedBox(height: 20),
    isAdmin
    ? ElevatedButton(
    onPressed: _deleteUser,
    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
    ),
    ),
    child: const Text('Удалить пользователя'),
    )
        : ElevatedButton(
    onPressed: _toggleFollow,
    style: ElevatedButton.styleFrom(
    backgroundColor: isFollowing ? Colors.grey : Colors.red,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
    ),
    ),
    child: Text(isFollowing ? 'Отписаться' : 'Подписаться'),
    ),
SizedBox(height: 30.0,),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: userVideos.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 3 / 3,
          crossAxisSpacing: 0.1,
        ),
        itemBuilder: (context, index) {
          final video = userVideos[index];
          final videoUrl = video['videoUrl'];
          final videoId = video['id'];

          return Center(
            child: kIsWeb
                ? AspectRatio(
              aspectRatio: 9 / 10,
              child: GestureDetector(
                onTap: () {
                  print("Clicked on video preview");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminVideoFullScreen(
                        videoId: videoId,
                        videoUrl: videoUrl,
                      ),
                    ),
                  );
                },
                child: AbsorbPointer(
                  absorbing: true,
                  child: VideoPlayerWidget(videoUrl: videoUrl),
                ),
              ),
            )
                : Container(),
          );
        },
      ),



    ],
        ),
      ),
    ))
    ;
  }
}


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
      _thumbnailPath = thumbnail?.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _thumbnailPath != null
        ? Image.file(File(_thumbnailPath!), fit: BoxFit.cover)
        : const Center(child: CircularProgressIndicator());
  }
}
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? AspectRatio(
      aspectRatio: 1 / 2,
      child: VideoPlayer(_controller),
    )
        : const Center(child: CircularProgressIndicator());
  }

}
