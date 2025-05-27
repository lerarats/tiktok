import 'package:flutter/material.dart';
import 'package:kurshachtt/screen/reel/user_profile_sreen_other.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'user_profile_screen.dart';
import 'profile_screen.dart';

class FollowingScreen extends StatefulWidget {
  final String uid;

  const FollowingScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}
class _FollowingScreenState extends State<FollowingScreen> {
  List<Map<String, dynamic>> followingUsers = [];
  String? currentUserId;
  String? currentUserRole;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserInfo();
    _fetchFollowingUsers();
  }

  Future<void> _fetchCurrentUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final userData = await Supabase.instance.client
          .from('user')
          .select('role')
          .eq('id', user.id)
          .single();

      setState(() {
        currentUserId = user.id;
        currentUserRole = userData['role'];
      });
    }
  }

  Future<void> _fetchFollowingUsers() async {
    try {
      final response = await Supabase.instance.client
          .from('followers')
          .select(
        'following_id, user:user!followers_following_id_fkey(user_name, profile_image_url)',
      )
          .eq('follower_id', widget.uid);

      setState(() {
        followingUsers = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching following users: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF272626),
      appBar: AppBar(

        title: const Text('Подписки', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : followingUsers.isEmpty
          ? const Center(
        child: Text(
          'Нет пользователей',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
      )
          : ListView.builder(
        itemCount: followingUsers.length,
        itemBuilder: (context, index) {
          final user = followingUsers[index]['user'];
          final userName = user['user_name'] ?? 'Unknown';
          final profileImageUrl = user['profile_image_url'] ??
              'https://example.com/default-avatar.png';
          final followingId = followingUsers[index]['following_id'];

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(profileImageUrl),
            ),
            title: Text(
              userName,
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              if (currentUserRole == 'admin') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(userId: followingId),
                  ),
                );
              } else if (followingId == currentUserId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(uid: currentUserId!),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        UserProfileScreenOther(userId: followingId),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
