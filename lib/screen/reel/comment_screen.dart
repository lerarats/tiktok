import 'package:flutter/material.dart';
import 'package:kurshachtt/screen/reel/profile_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_screen.dart';
import 'package:kurshachtt/screen/reel/user_profile_sreen_other.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as tago;

class CommentScreen extends StatefulWidget {
  final String videoId;
  final String? highlightedCommentId;
  final String? videoOwnerId;
  const CommentScreen({Key? key, required this.videoId,this.highlightedCommentId,  this.videoOwnerId,}) : super(key: key);

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> comments = [];
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _fetchComments();
  }


  Future<void> _fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      try {

        final response = await Supabase.instance.client
            .from('user')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        setState(() {
          currentUserRole = response?['role'];
        });
      } catch (e) {
        print("Ошибка загрузки роли пользователя: $e");
      }
    }
  }


  Future<void> _fetchComments() async {
    try {
      final response = await Supabase.instance.client
          .from('comments')
          .select('*, user(user_name, profile_image_url)')
          .eq('video_id', widget.videoId)
          .order('created_at', ascending: false);

      setState(() {
        comments = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("Ошибка загрузки комментариев: $e");
    }
  }


  Future<void> _postComment() async {
    if (_commentController.text
        .trim()
        .isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Вы должны войти в систему, чтобы оставить комментарий!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final newComment = {
        'video_id': widget.videoId,
        'user_id': user.id,
        'comment_text': _commentController.text.trim(),
      };


      await Supabase.instance.client.from('comments').insert(newComment);


      await Supabase.instance.client
          .from('videos')
          .update({
        'commentCount': (comments.length + 1),
      })
          .eq('id', widget.videoId);

      _commentController.clear();
      _fetchComments();
    } catch (e) {
      print("Ошибка отправки комментария: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки комментария: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _deleteComment(String commentId) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Вы должны войти в систему, чтобы удалить комментарий!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final comment = comments.firstWhere((comment) =>
    comment['id'] == commentId);


    if (currentUserRole == 'admin' || comment['user_id'] == user.id) {

      bool? confirmDelete = await _showDeleteDialog();

      if (confirmDelete == true) {
        try {

          await Supabase.instance.client.from('comments').delete().eq(
              'id', commentId);


          await Supabase.instance.client
              .from('videos')
              .update({
            'commentCount': (comments.length - 1),
          })
              .eq('id', widget.videoId);


          _fetchComments();
        } catch (e) {
          print("Ошибка удаления комментария: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления комментария: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Вы можете удалить только свои комментарии!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<bool?> _showDeleteDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Подтверждение удаления'),
          content: const Text(
              'Вы уверены, что хотите удалить этот комментарий?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Нет'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Да'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReportDialog(String commentId,
      String reportedUserId) async {
    final reasons = ['Спам', 'Оскорбление', 'Неприемлемый контент', 'Другое'];
    String? selectedReason;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Пожаловаться на комментарий'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((reason) {
              return RadioListTile<String>(
                title: Text(reason),
                value: reason,
                groupValue: selectedReason,
                onChanged: (value) {
                  selectedReason = value;
                  Navigator.of(context).pop();
                  if (value != null) {
                    _submitReport(commentId, reportedUserId, value);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _submitReport(String commentId, String reportedUserId,
      String reason) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': user.id,

        'reported_comment_id': commentId,
        'reason': reason,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Жалоба отправлена'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Ошибка при отправке жалобы: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при отправке жалобы: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery
        .of(context)
        .size;

    return Scaffold(
      backgroundColor: const Color(0xFF272626),
      appBar: AppBar(
        title: const Text('Комментарии', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        leading: IconButton(
          color: Colors.white,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, comments.length);

          },
        ),

      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                final profile = comment['user'];

                return GestureDetector(
                  onLongPress: () {
                    _deleteComment(comment['id']);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.highlightedCommentId == comment['id']
                          ? Colors.red.withOpacity(0.1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          final currentUser = Supabase.instance.client.auth.currentUser;

                          if (currentUser != null && currentUser.id == comment['user_id']) {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(uid: currentUser.id),
                              ),
                            );
                          }
                          else if (currentUserRole == 'admin') {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(userId: comment['user_id']),
                              ),
                            );
                          }else {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>  UserProfileScreenOther(
                                  userId: comment['user_id'],
                                ),
                              ),
                            );
                          }
                        },
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(profile['profile_image_url']),
                        ),
                      ),


                      title: Text(
                        profile?['user_name'] ?? 'Аноним',
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment['comment_text'] ?? '',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white),
                          ),
                          Text(
                            tago.format(DateTime.parse(comment['created_at'])),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'report') {
                            _showReportDialog(
                                comment['id'], comment['user_id']);
                          } else if (value == 'delete') {
                            _deleteComment(comment['id']);
                          }
                        },
                        itemBuilder: (context) {
                          List<PopupMenuEntry<String>> items = [];

                          final user = Supabase.instance.client.auth
                              .currentUser;
                          final isOwnerOrAdmin = currentUserRole == 'admin' ||
                              comment['user_id'] == user?.id ||
                              widget.videoOwnerId == user?.id;

                          final isOwnComment = comment['user_id'] == user?.id;


                          if (currentUserRole != 'admin' && !isOwnComment) {
                            items.add(
                              const PopupMenuItem(
                                value: 'report',
                                child: Text('Пожаловаться',
                                    style: TextStyle(color: Colors.black)),
                              ),
                            );
                          }


                          if (isOwnerOrAdmin) {
                            items.insert(
                              0,
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить',
                                    style: TextStyle(color: Colors.black)),
                              ),
                            );
                          }

                          return items;
                        },
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white),
          if (currentUserRole != 'admin')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _commentController,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Написать комментарий...',
                        labelStyle: TextStyle(
                          color: Colors.white70,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _postComment,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
