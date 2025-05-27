import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<List<Map<String, dynamic>>> fetchVideos() async {
  final response = await supabase
      .from('videos')
      .select('*, user:uid(id, user_name, profile_image_url)')
      .order('created_at', ascending: false);

  for (var video in response) {
    print(" Video URL: ${video['videoUrl']}");
  }

  if (response != null) {
    return response;
  } else {
    throw Exception(response);
  }
}

Future<void> toggleLike(String videoId, String userId) async {
  final video = await supabase.from('videos').select().eq('id', videoId).single();

  if (video == null) return;

  List likedBy = video['likedby'] ?? [];

  if (likedBy.contains(userId)) {

    likedBy.remove(userId);
    await supabase.from('videos').update({
      'likedby': likedBy,
      'likes': video['likes'] - 1,
    }).eq('id', videoId);
  } else {

    likedBy.add(userId);
    await supabase.from('videos').update({
      'likedby': likedBy,
      'likes': video['likes'] + 1,
    }).eq('id', videoId);
  }
}
Future<void> updateVideoLikes(String videoId, String userId, bool isLiked) async {
  try {
    final response = await supabase
        .from('videos')
        .select('likedby, likes')
        .eq('id', videoId)
        .single();

    if (response == null) return;

    List<String> likedBy = List<String>.from(response['likedby'] ?? []);
    int currentLikes = response['likes'] ?? 0;

    if (isLiked) {
      likedBy.add(userId);
      currentLikes += 1;
    } else {
      likedBy.remove(userId);
      currentLikes -= 1;
    }

    await supabase.from('videos').update({
      'likedby': likedBy,
      'likes': currentLikes,
    }).eq('id', videoId);
  } catch (e) {
    print(" Ошибка при обновлении лайков: $e");
  }
}

