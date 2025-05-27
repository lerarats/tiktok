import 'package:flutter/material.dart';
import 'package:kurshachtt/screen/reel/user_profile_screen.dart';
import 'package:kurshachtt/screen/reel/profile_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_sreen_other.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FollowersScreen extends StatefulWidget {
  final String uid;
  final bool isFollowers;

  const FollowersScreen({Key? key, required this.uid, required this.isFollowers}) : super(key: key);

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}
class _FollowersScreenState extends State<FollowersScreen> {
  List<Map<String, dynamic>> users = [];
  String screenTitle = '';
  String? currentUserId;
  String? currentUserRole;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    screenTitle = widget.isFollowers ? 'Подписчики' : 'Подписчики';
    _getCurrentUserInfo().then((_) => _fetchUsers());
  }

  Future<void> _getCurrentUserInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      currentUserId = user.id;

      final userData = await Supabase.instance.client
          .from('user')
          .select('role')
          .eq('id', currentUserId!)

          .single();

      setState(() {
        currentUserRole = userData['role'];
      });
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await Supabase.instance.client
          .from('followers')
          .select(
          'follower_id:user!followers_follower_id_fkey(id, user_name, profile_image_url)')
          .eq('following_id', widget.uid);

      setState(() {
        users = response.map<Map<String, dynamic>>((item) => item['follower_id']).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching users: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF272626),
      appBar: AppBar(

        title: Text(
          screenTitle,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(
        child: Text(
          'Нет пользователей',
          style: TextStyle(color: Colors.white),
        ),
      )
          : ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final userName = user['user_name'] ?? 'Unknown';
          final profileImageUrl = user['profile_image_url'] ??
              'https://example.com/default-avatar.png';
          final followerId = user['id'];

          if (followerId == null) {
            print('Error: followerId is null');
            return const SizedBox.shrink();
          }

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
                    builder: (context) => UserProfileScreen(userId: followerId),
                  ),
                );
              } else if (followerId == currentUserId) {
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
                        UserProfileScreenOther(userId: followerId),
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
