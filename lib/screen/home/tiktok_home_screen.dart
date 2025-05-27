import 'package:flutter/material.dart';
import 'package:kurshachtt/provider/nav/nav_provider.dart';
import 'package:kurshachtt/screen/reel/add_video_screen.dart';
import 'package:kurshachtt/screen/reel/chat_screen.dart';

import 'package:kurshachtt/screen/reel/profile_screen.dart';
import 'package:kurshachtt/screen/reel/profile_stat_screen.dart';
import 'package:kurshachtt/screen/reel/reel_screen.dart';
import 'package:kurshachtt/screen/reel/search_screen.dart';
import 'package:provider/provider.dart';

import '../../component/nav/bottom_navigation.dart';

class TiktokHomeScreen extends StatelessWidget {
  final String userId;

  const TiktokHomeScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NavProvider()),
      ],
      child: TiktokPage(userId: userId),
    );
  }
}

class TiktokPage extends StatelessWidget {
  final String userId;

  const TiktokPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<NavProvider>(
        builder: (context, value, child) => IndexedStack(
          index: value.pageIndex,
          children: [
            RealScreen(currentUserId: userId),
            SearchScreen(),
            AddVideoScreen(),
            ProfileStatsScreen(uid: userId),
            ProfileScreen(uid: userId),
          ],
        ),
      ),
      bottomNavigationBar: Consumer<NavProvider>(
        builder: (context, value, child) =>
            TiktokBottomNavigation(selectIndex: value.pageIndex),
      ),
    );
  }
}
