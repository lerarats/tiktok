import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../Controllers/video_preview.dart';
import 'video_full_screen.dart';

class ProfileStatsScreen extends StatefulWidget {
  final String uid;

  const ProfileStatsScreen({Key? key, required this.uid}) : super(key: key);

  @override
  _ProfileStatsScreenState createState() => _ProfileStatsScreenState();
}

enum ActivityPeriod { day, week, month }

class _ProfileStatsScreenState extends State<ProfileStatsScreen> {
  Map<String, dynamic>? topVideo;
  ActivityPeriod _selectedPeriod = ActivityPeriod.day;
  int newFollowers = 0;

  int maleFollowers = 0;
  int femaleFollowers = 0;

  @override
  void initState() {
    super.initState();
    _fetchTopVideo();
    _fetchFollowersStats();
    _fetchGenderStats();
  }

  Future<void> _fetchTopVideo() async {
    try {
      final videos = await Supabase.instance.client
          .from('videos')
          .select('id, videoUrl, likes, uid')
          .eq('uid', widget.uid);

      if (videos == null || videos.isEmpty) {
        setState(() {
          topVideo = null;
        });
        return;
      }

      List<Map<String, dynamic>> enrichedVideos = [];

      for (var video in videos) {
        final comments = await Supabase.instance.client
            .from('comments')
            .select()
            .eq('video_id', video['id']);

        enrichedVideos.add({
          ...video,
          'commentCount': comments.length,
        });
      }

      enrichedVideos.sort((a, b) {
        int aScore = a['likes'] + a['commentCount'];
        int bScore = b['likes'] + b['commentCount'];
        return bScore.compareTo(aScore);
      });

      setState(() {
        topVideo = enrichedVideos.isNotEmpty ? enrichedVideos.first : null;
      });
    } catch (e) {
      print('Ошибка при загрузке статистики: $e');
      setState(() {
        topVideo = null;
      });
    }
  }


  Future<void> _fetchFollowersStats() async {
    try {
      DateTime now = DateTime.now();
      DateTime from;

      switch (_selectedPeriod) {
        case ActivityPeriod.day:
          from = now.subtract(const Duration(days: 1));
          break;
        case ActivityPeriod.week:
          from = now.subtract(const Duration(days: 7));
          break;
        case ActivityPeriod.month:
          from = now.subtract(const Duration(days: 30));
          break;
      }

      final response = await Supabase.instance.client
          .from('followers')
          .select()
          .eq('following_id', widget.uid)
          .gte('created_at', from.toIso8601String());

      setState(() {
        newFollowers = response.length;
      });
    } catch (e) {
      print("Ошибка при получении подписчиков: $e");
    }
  }

  Future<void> _fetchGenderStats() async {
    try {
      final response = await Supabase.instance.client
          .from('followers')
          .select('follower_id')
          .eq('following_id', widget.uid);

      List<String> followerIds = List<String>.from(
          response.map((f) => f['follower_id']));

      final profiles = await Supabase.instance.client
          .from('user')
          .select('id, gender')
          .inFilter('id', followerIds);

      int males = 0;
      int females = 0;

      for (var user in profiles) {
        if (user['gender'] == 'Мужской') males++;
        if (user['gender'] == 'Женский') females++;
      }

      setState(() {
        maleFollowers = males;
        femaleFollowers = females;
      });
    } catch (e) {
      print("Ошибка при получении пола подписчиков: $e");
    }
  }

  Future<void> _refreshAll() async {
    await _fetchTopVideo();
    await _fetchFollowersStats();
    await _fetchGenderStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF272626),
      appBar: AppBar(
        automaticallyImplyLeading: false,


        title: const Text(
            'Статистика профиля', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Самое популярное видео",
                    style: TextStyle(fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 15),

                  topVideo == null
                      ? const Center(child: Text("Нет популярных видео.",
                      style: TextStyle(color: Colors.white)))
                      : SizedBox(
                    width: 100,
                    height: 150,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                VideoPlayerFullScreen(
                                  videoUrl: topVideo!['videoUrl'],
                                  videoId: topVideo!['id'],
                                ),
                          ),
                        );
                      },
                      child: VideoThumbnailWidget(
                        key: ValueKey(topVideo!['id']),
                        videoPath: topVideo!['videoUrl'],
                      ),
                    ),
                  ),
                  if (topVideo != null) ...[
                    const SizedBox(height: 15),
                    Text("❤️ Лайки: ${topVideo!['likes']}",
                        style: const TextStyle(color: Colors.white)),
                    Text("💬 Комментарии: ${topVideo!['commentCount']}",
                        style: const TextStyle(color: Colors.white)),
                  ],
                  const SizedBox(height: 30),
                  const Divider(color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    "Активность",
                    style: TextStyle(fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: Colors.black,
                    ),
                    child: DropdownButton<ActivityPeriod>(
                      dropdownColor: Colors.black,
                      value: _selectedPeriod,
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                          value: ActivityPeriod.day,
                          child: Text("День",
                              style: TextStyle(color: Colors.white)),
                        ),
                        DropdownMenuItem(
                          value: ActivityPeriod.week,
                          child: Text("Неделя",
                              style: TextStyle(color: Colors.white)),
                        ),
                        DropdownMenuItem(
                          value: ActivityPeriod.month,
                          child: Text("Месяц",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedPeriod = value;
                          });
                          _fetchFollowersStats();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text("📈 Подписалось: +$newFollowers",
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 30),
                  const Divider(color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(
                    "Соотношение подписчиков по полу",
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 1.2,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: femaleFollowers.toDouble(),
                            title: '',
                            color: Colors.pinkAccent,
                            radius: 60,
                          ),
                          PieChartSectionData(
                            value: maleFollowers.toDouble(),
                            title: '',
                            color: Colors.lightBlueAccent,
                            radius: 60,
                          ),
                        ],
                        sectionsSpace: 16,
                        centerSpaceRadius: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        color: Colors.pinkAccent,
                      ),
                      const SizedBox(width: 6),
                      Text("Женщин: $femaleFollowers",
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 20),
                      Container(
                        width: 12,
                        height: 12,
                        color: Colors.lightBlueAccent,
                      ),
                      const SizedBox(width: 6),
                      Text("Мужчин: $maleFollowers",
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
