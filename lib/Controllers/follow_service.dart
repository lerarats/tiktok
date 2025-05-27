import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<bool> isUserFollowing(String currentUserId, String userId) async {
  final response = await supabase
      .from('followers')
      .select()
      .eq('follower_id', currentUserId)
      .eq('following_id', userId)
      .maybeSingle();

  return response != null;
}


Future<void> toggleFollow(String currentUserId, String userId) async {
  bool isFollowing = await isUserFollowing(currentUserId, userId);

  if (isFollowing) {
    await supabase
        .from('followers')
        .delete()
        .match({'follower_id': currentUserId, 'following_id': userId});
  } else {
    await supabase.from('followers').insert({
      'follower_id': currentUserId,
      'following_id': userId,
    });
  }
}
