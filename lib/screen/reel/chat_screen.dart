import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;

  const ChatScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> chats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  Future<void> _fetchChats() async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('*, users!inner(id, user_name, profile_image_url)')
          .or('sender_id.eq.${widget.currentUserId},receiver_id.eq.${widget.currentUserId}')
          .order('created_at', ascending: false);

      if (response != null && response.isNotEmpty) {
        setState(() {
          chats = List<Map<String, dynamic>>.from(response);
        });
      } else {
        setState(() {
          chats = [];
        });
      }
    } catch (e) {
      print('Error fetching chats: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.black12,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : chats.isEmpty
          ? const Center(child: Text('Начните общение!'))
          : ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          final user = chat['users'];
          final userName = user['user_name'] ?? 'Unknown';
          final profileImageUrl = user['profile_image_url'] ??
              'https://example.com/default-avatar.png';
          final lastMessage = chat['message'];

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(profileImageUrl),
            ),
            title: Text(userName),
            subtitle: Text(lastMessage ?? 'Нет сообщений'),
            onTap: () {

            },
          );
        },
      ),
    );
  }
}
