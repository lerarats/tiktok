import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kurshachtt/screen/reel/user_profile_screen.dart';
import 'package:kurshachtt/screen/reel/video_full_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_comment_screen.dart';
import 'admin_video_full_screen.dart';
import 'comment_screen.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> reports = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final response = await Supabase.instance.client
          .from('reports')
          .select('id, reporter_id, reported_user_id, reported_video_id, reported_comment_id, reason, created_at');
      setState(() {
        reports = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('Ошибка при загрузке жалоб: $e');
      setState(() => isLoading = false);
    }
  }

  Future<String> _getUserName(String userId) async {
    final resp = await Supabase.instance.client
        .from('user')
        .select('user_name')
        .eq('id', userId)
        .maybeSingle();
    return resp?['user_name'] ?? 'Неизвестный';
  }

  Future<Map<String, dynamic>?> _getCommentDetail(String commentId) async {
    final resp = await Supabase.instance.client
        .from('comments')
        .select('comment_text, video_id, user(user_name)')
        .eq('id', commentId)
        .maybeSingle();
    return resp;
  }

  Future<String?> _getVideoUrl(String videoId) async {
    final resp = await Supabase.instance.client
        .from('videos')
        .select('videoUrl')
        .eq('id', videoId)
        .maybeSingle();
    return resp?['videoUrl'];
  }

  Future<void> _deleteReport(String reportId) async {
    try {
      await Supabase.instance.client
          .from('reports')
          .delete()
          .eq('id', reportId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Жалоба удалена")));
      _fetchReports();
    } catch (e) {
      print('Ошибка при удалении жалобы: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка при удалении")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Жалобы'),
          backgroundColor: Colors.black12,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchReports,
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Пользователи'),
              Tab(text: 'Видео'),
              Tab(text: 'Комментарии'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            _buildUserReports(),
            _buildVideoReports(),
            _buildCommentReports(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserReports() {
    final userReports = reports.where((r) => r['reported_user_id'] != null).toList();
    if (userReports.isEmpty) return const Center(child: Text("Жалоб на пользователей нет"));
    return ListView.builder(
      itemCount: userReports.length,
      itemBuilder: (ctx, i) {
        final rpt = userReports[i];
        return FutureBuilder<List<String>>(
          future: Future.wait([
            _getUserName(rpt['reporter_id']),
            _getUserName(rpt['reported_user_id']),
          ]),
          builder: (ctx, snap) {
            if (!snap.hasData) return const ListTile(title: Text("Загрузка..."));
            final reporter = snap.data![0];
            final reported = snap.data![1];

            return ListTile(
              title: Text('$reporter пожаловался на $reported'),
              subtitle: Text('Причина: ${rpt['reason']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(rpt['created_at'].toString().substring(0, 10)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Удалить жалобу?"),
                          content: const Text("Вы уверены, что хотите удалить эту жалобу?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Удалить", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );

                      if (shouldDelete == true) {
                        await _deleteReport(rpt['id']);
                      }
                    },
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: rpt['reported_user_id']),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideoReports() {
    final vids = reports.where((r) => r['reported_video_id'] != null).toList();
    if (vids.isEmpty) return const Center(child: Text("Жалоб на видео нет"));
    return ListView.builder(
      itemCount: vids.length,
      itemBuilder: (ctx, i) {
        final rpt = vids[i];
        return FutureBuilder<String>(
          future: _getUserName(rpt['reporter_id']),
          builder: (ctx, snapR) {
            if (!snapR.hasData) return const ListTile(title: Text("Загрузка..."));
            return FutureBuilder<String?>(
              future: _getVideoUrl(rpt['reported_video_id']),
              builder: (ctx, snapV) {
                if (!snapV.hasData) return const ListTile(title: Text("Загрузка..."));
                final url = snapV.data;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: ListTile(
                    title: Text('${snapR.data} пожаловался на видео'),
                    subtitle: Text('Причина: ${rpt['reason']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(rpt['created_at'].toString().substring(0, 10)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Удалить жалобу?"),
                                content: const Text("Вы уверены, что хотите удалить эту жалобу?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Удалить", style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );

                            if (shouldDelete == true) {
                              await _deleteReport(rpt['id']);
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: url == null
                        ? null
                        : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminVideoFullScreen(
                          videoId: rpt['reported_video_id'],
                          videoUrl: url,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommentReports() {
    final cmts = reports.where((r) => r['reported_comment_id'] != null).toList();
    if (cmts.isEmpty) return const Center(child: Text("Жалоб на комментарии нет"));

    return ListView.builder(
      itemCount: cmts.length,
      itemBuilder: (context, index) {
        final rpt = cmts[index];
        return FutureBuilder<Map<String, dynamic>?>(
          future: _getCommentDetail(rpt['reported_comment_id']),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData) {
              return const ListTile(title: Text("Загрузка..."));
            }

            final comment = snapshot.data!;
            final commentText = comment['comment_text'];
            final videoId = comment['video_id'];
            final commentUser = comment['user']['user_name'] ?? 'Неизвестный';

            return ListTile(
              title: Text('Жалоба на комментарий'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Причина: ${rpt['reason']}'),
                  const SizedBox(height: 4),
                  Text('Комментарий: $commentText'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(rpt['created_at'].toString().substring(0, 10)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Удалить жалобу?"),
                          content: const Text("Вы уверены, что хотите удалить эту жалобу?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Удалить", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );

                      if (shouldDelete == true) {
                        await _deleteReport(rpt['id']);
                      }
                    },
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminCommentScreen(
                    videoId: videoId,
                    highlightedCommentId: rpt['reported_comment_id'],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
