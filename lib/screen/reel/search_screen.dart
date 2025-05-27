import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kurshachtt/Controllers/searching_controller.dart' as custom;
import 'package:kurshachtt/screen/reel/profile_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_sreen_other.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final searchController = Get.put(custom.SearchController());
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    return WillPopScope(
      onWillPop: () async {
        searchController.clearSearch();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF272626),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.black,
          title: TextField(
            onChanged: (value) => searchController.searchUser(value),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Поиск',
              hintStyle: TextStyle(color: Colors.white, fontSize: 18),
              border: InputBorder.none,
            ),
          ),
        ),
        body: Obx(() {
          if (searchController.searchedUsers.isEmpty) {
            return const Center(
              child: Text(
                '',
                style: TextStyle(fontSize: 25, color: Colors.white),
              ),
            );
          }


          final filteredUsers = searchController.searchedUsers.where((user) {
            return user.email != 'admin@gmail.com';
          }).toList();

          return ListView.builder(
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];

              return ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage: user.profileImageUrl != null
                      ? CachedNetworkImageProvider(user.profileImageUrl!)
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                ),
                title: Text(
                  user.userName,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  user.email,
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  if (user.id == currentUser?.id) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(uid: currentUser!.id),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreenOther(userId: user.id),
                      ),
                    );
                  }
                },
              );
            },
          );
        }),
      ),
    );
  }
}
