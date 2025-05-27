import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageScreen extends StatefulWidget {
  final String receiverId;

  const MessageScreen({Key? key, required this.receiverId}) : super(key: key);

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  TextEditingController _controller = TextEditingController();

  Future<void> _sendMessage() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null && _controller.text.isNotEmpty) {
      try {
        await Supabase.instance.client.from('messages').insert([
          {
            'sender_id': currentUserId,
            'receiver_id': widget.receiverId,
            'content': _controller.text,
            'created_at': DateTime.now().toIso8601String()
          }
        ]);

        _controller.clear();

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сообщение отправлено')));
      } catch (e) {
        print("Ошибка отправки сообщения: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка отправки сообщения')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Написать сообщение'),
        backgroundColor: Colors.black12,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Введите ваше сообщение...',
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sendMessage,
              child: const Text('Отправить'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
