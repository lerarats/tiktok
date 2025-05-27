import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kurshachtt/repository/tables/user_table.dart';

class SearchController extends GetxController {
  var searchedUsers = <CustomUser>[].obs;
  void clearSearch() {
    searchedUsers.clear();
  }

  Future<void> searchUser(String query) async {
    if (query.isEmpty) {
      searchedUsers.clear();
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('user')
          .select()
          .ilike('user_name', '%$query%');

      final data = response as List<dynamic>;
      searchedUsers.value = data.map((user) => CustomUser.fromJson(user)).toList();
    } catch (e) {
      print('Ошибка при поиске пользователей: $e');
    }
  }
}


