import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kurshachtt/screen/reel/video_full_screen.dart';
import 'package:kurshachtt/screen/reel/view_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../Controllers/video_preview.dart';
import '../../Controllers/video_player.dart';
import '../../constants.dart';
import 'followers_screen.dart';
import 'following_screen.dart';
import 'login_screen.dart';


class ProfileScreen extends StatefulWidget {
  final String uid;

  const ProfileScreen({Key? key, required this.uid}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? profileImageUrl;
  String? userName;
  String? userDescription;
  List<Map<String, dynamic>> userVideos = [];
  int totalLikes = 0;
  int followingCount = 0;
  int followerCount = 0;
  String? userGender;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchUserVideos();
    _fetchTotalLikes();
    _fetchFollowingAndFollowers();
    _subscribeToVideoChanges();
  }

  void _subscribeToVideoChanges() {
    Supabase.instance.client
        .from('videos')
        .stream(primaryKey: ['id'])
        .eq('uid', widget.uid)
        .listen((event) {
      _fetchUserVideos();
    });
  }



  Future<void> _fetchFollowingAndFollowers() async {
    try {
      final followingResponse = await Supabase.instance.client
          .from('followers')
          .select()
          .eq('follower_id', widget.uid);

      final followersResponse = await Supabase.instance.client
          .from('followers')
          .select()
          .eq('following_id', widget.uid);

      setState(() {
        followingCount = followingResponse.length;
        followerCount = followersResponse.length;
      });
    } catch (e) {
      print("Error fetching followers/following: $e");
    }
  }

  Future<void> _fetchUserVideos() async {
    try {
      final response = await Supabase.instance.client
          .from('videos')
          .select('id, videoUrl, uid')
          .eq('uid', widget.uid);

      setState(() {
        userVideos = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("Error loading videos: $e");
    }
  }
  Key _pageKey = UniqueKey();

  Future<void> _refreshPage() async {
    await Future.wait([
      _fetchUserData(),
      _fetchUserVideos(),
      _fetchTotalLikes(),
      _fetchFollowingAndFollowers(),
    ]);

    setState(() {
      _pageKey = UniqueKey();
    });
  }




  Future<void> _fetchUserData() async {
    try {
      final response = await Supabase.instance.client
          .from('user')
          .select('user_name, profile_image_url, description, gender')
          .eq('id', widget.uid)
          .maybeSingle();

      setState(() {
        userName = response?['user_name'] ?? 'User';
        profileImageUrl = response?['profile_image_url'] ?? 'https://example.com/default-avatar.png';
        userDescription = response?['description'] ?? 'No description yet';
        userGender = response?['gender'] ?? 'Не указан';
      });
    } catch (e) {
      print("Error $e");
    }
  }

  Future<void> _fetchTotalLikes() async {
    try {
      final response = await Supabase.instance.client
          .from('videos')
          .select('likes')
          .eq('uid', widget.uid);

      setState(() {
        totalLikes = response.fold<int>(
          0,
              (sum, item) => sum + (item['likes'] as int),
        );
      });
    } catch (e) {
      print("Error calculating likes: $e");
    }
  }
  Future<void> _deleteVideo(String videoId, String videoUrl) async {
    try {
      final videoPath = videoUrl.replaceFirst(
        'https://<supabase-url>/storage/v1/object/public/videos/',
        '',
      );

      await Supabase.instance.client
          .from('videos')
          .delete()
          .eq('id', videoId);

      await Supabase.instance.client.storage.from('videos').remove([videoPath]);


      setState(() {
        userVideos.removeWhere((video) => video['id'] == videoId);
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Видео успешно удалено.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print('Ошибка при удалении видео: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Не удалось удалить видео: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }


  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();


    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Выбрать из галереи'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Сделать фото'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    File file = File(pickedFile.path);
    String path = 'profile_images/${widget.uid}.jpg';

    try {
      await Supabase.instance.client.storage
          .from('photos')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage.from('photos').getPublicUrl(path);

      await Supabase.instance.client
          .from('user')
          .update({'profile_image_url': publicUrl})
          .eq('id', widget.uid);

      setState(() {
        profileImageUrl = '$publicUrl?timestamp=${DateTime.now().millisecondsSinceEpoch}';
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Фото профиля обновлено!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print('Ошибка загрузки изображения: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ошибка загрузки: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _showEditProfileDialog() async {
    String? _selectedGender = userGender ?? 'Не указан';

    _usernameController.text = userName ?? '';
    _descriptionController.text = userDescription ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Редактировать профиль'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Введите новое имя пользователя'),
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(labelText: 'Пол'),
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      items: ['Мужской', 'Женский', 'Не указан'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGender = newValue!;
                        });
                      },
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Введите новое описание профиля'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showChangePasswordDialog();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Изменить пароль'),
                    ),

                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              actions: [
              Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: buttonStyle,
                  child: const Text('Отмена'),
                ),const SizedBox(width: 36),

                TextButton(
                  onPressed: () async {
                    final newUsername = _usernameController.text.trim();
                    final newDescription = _descriptionController.text.trim();

                    final updateData = <String, dynamic>{};
                    if (newUsername.isNotEmpty) updateData['user_name'] = newUsername;
                    if (newDescription.isNotEmpty) updateData['description'] = newDescription;
                    if (_selectedGender != null) updateData['gender'] = _selectedGender;

                    await Supabase.instance.client
                        .from('user')
                        .update(updateData)
                        .eq('id', widget.uid);

                    this.setState(() {
                      if (newUsername.isNotEmpty) userName = newUsername;
                      if (newDescription.isNotEmpty) userDescription = newDescription;
                    });

                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Профиль обновлен!'),
                      backgroundColor: Colors.green,
                    ));
                  },
                  style: buttonStyle,
                  child: const Text('Сохранить'),
                ),
              ],
            )]);
          },
        );
      },
    );
  }
  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    String? passwordError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Изменить пароль'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Старый пароль'),
                  ),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Новый пароль'),
                  ),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Подтвердите новый пароль'),
                  ),
                  if (passwordError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        passwordError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: buttonStyle,
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 26),
                  TextButton(
                    onPressed: () async {
                      final oldPass = oldPasswordController.text.trim();
                      final newPass = newPasswordController.text.trim();
                      final confirmPass = confirmPasswordController.text.trim();

                      setState(() {
                        passwordError = null;
                      });

                      final regex = RegExp(r'^(?=.*\d)[A-Za-z\d]{6,12}$');

                      if (newPass != confirmPass) {
                        setState(() {
                          passwordError = 'Пароли не совпадают';
                        });
                        return;
                      }

                      if (!regex.hasMatch(newPass)) {
                        setState(() {
                          passwordError = 'Пароль должен быть от 6 до 12 символов и содержать хотя бы одну цифру';
                        });
                        return;
                      }

                      try {
                        final user = Supabase.instance.client.auth.currentUser;
                        final email = user?.email;

                        if (email == null) {
                          setState(() {
                            passwordError = 'Не удалось определить пользователя';
                          });
                          return;
                        }

                        try {
                          await Supabase.instance.client.auth.signInWithPassword(
                            email: email,
                            password: oldPass,
                          );
                        } on AuthException catch (_) {
                          setState(() {
                            passwordError = 'Неверный старый пароль';
                          });
                          return;
                        } catch (e) {
                          setState(() {
                            passwordError = 'Ошибка при проверке пароля: $e';
                          });
                          return;
                        }





                        if (oldPass == newPass) {
                          setState(() {
                            passwordError = 'Новый пароль не должен совпадать со старым';
                          });
                          return;
                        }


                        final response = await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPass),
                        );

                        if (response.user == null) {
                          setState(() {
                            passwordError = 'Ошибка при обновлении пароля';
                          });
                          return;
                        }

                        Navigator.of(context).pop();

                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Пароль успешно изменен!'),
                          backgroundColor: Colors.green,
                        ));
                      } catch (e) {
                        setState(() {
                          passwordError = 'Ошибка при изменении пароля: $e';
                        });
                      }
                    },
                    style: buttonStyle,
                    child: const Text('Сохранить'),
                  ),
                ],
              )
            ],
          );
        });
      },
    );
  }




  Future<String> _hashPassword(String password) async {
    final hashedPassword = await BCrypt.hashpw(password, BCrypt.gensalt());
    return hashedPassword;
  }


  Future<void> signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isCurrentUser = widget.uid == currentUserId;

    return KeyedSubtree(
        key: _pageKey,
        child: Scaffold(
      backgroundColor: Color(0xFF272626),
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app, color: Colors.white,),
          onPressed: () => signOut(context),
        ),
        title: Text(userName ?? 'Профиль', style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          if (isCurrentUser)
            IconButton(
              color: Colors.white,
              icon: const Icon(Icons.edit),
              onPressed: _showEditProfileDialog,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ClipOval(
                    child: CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: profileImageUrl ?? '',
                      height: 100,
                      width: 100,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.error, size: 80),
                    ),
                  ),
                  if (isCurrentUser)
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black45,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.camera_alt, color: Colors.white),
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
                              builder: (context) => FollowingScreen(uid: widget.uid),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Text('$followingCount',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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
                          builder: (context) => FollowersScreen(uid: widget.uid, isFollowers: false),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text('$followerCount',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,color: Colors.white)),
                        const SizedBox(height: 5),
                        const Text('Подписчики', style: TextStyle(fontSize: 14, color: Colors.white)),
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
                      Text('$totalLikes',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 5),
                      const Text('Лайки', style: TextStyle(fontSize: 14, color: Colors.white)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Text(userDescription ?? 'Описания нет',
                  style: const TextStyle(fontSize: 16, color: Colors.white)),
              const SizedBox(height: 15),
              if (userVideos.isEmpty)
                const Center(
                  child: Text('Нет видео',
                      style: TextStyle(fontSize: 16, color: Colors.white70)),
                ),

              if (userVideos.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: userVideos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 5,
                  ),
                  itemBuilder: (context, index) {
                    final videoUrl = userVideos.reversed.toList()[index]['videoUrl'];
                    final videoId = userVideos.reversed.toList()[index]['id'];
                    final authorId = userVideos.reversed.toList()[index]['uid'];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerFullScreen(
                              videoUrl: videoUrl,
                              videoId: videoId,
                            ),

                          ),
                        );
                      },

                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Удаление видео'),
                              content: const Text('Вы уверены, что хотите удалить это видео?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Отмена'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    await _deleteVideo(videoId, videoUrl);


                                    await _refreshPage();
                                    setState(() {});
                                  },
                                  child: const Text('Удалить'),
                                ),

                              ],
                            );
                          },
                        );
                      },
                      child: VideoThumbnailWidget(videoPath: videoUrl),
                    );
                  },
                )

            ],
          ),
        ),
      ),
        )
    );
  }
}
