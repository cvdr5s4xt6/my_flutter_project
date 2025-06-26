import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';

class ReviewCommentsPage extends StatefulWidget {
  final int reviewId;
  const ReviewCommentsPage({super.key, required this.reviewId});

  @override
  State<ReviewCommentsPage> createState() => _ReviewCommentsPageState();
}

class _ReviewCommentsPageState extends State<ReviewCommentsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();

  Future<List<Map<String, dynamic>>> _loadComments() async {
    final res = await supabase
        .from('review_comments')
        .select(
          'comment_id, comment, created_at, user_id ( first_name, last_name )',
        )
        .eq('review_id', widget.reviewId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: пользователь не авторизован')),
      );
      return;
    }

    try {
      await supabase.from('review_comments').insert({
        'review_id': widget.reviewId,
        'user_id': userId,
        'comment': text,
      });

      _commentController.clear();

      // Возвращаем true, чтобы родительская страница поняла, что нужно обновить данные
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при отправке комментария: $e')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Комментарии')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadComments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final comments = snapshot.data ?? [];

                if (comments.isEmpty) {
                  return const Center(child: Text('Пока нет комментариев'));
                }

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final c = comments[index];
                    final user = c['user_id'] as Map<String, dynamic>;
                    final date = DateTime.tryParse(c['created_at'] ?? '');
                    final formattedDate = date != null
                        ? DateFormat('dd.MM.yy HH:mm').format(date)
                        : '';

                    return ListTile(
                      title: Text('${user['first_name']} ${user['last_name']}'),
                      subtitle: Text(c['comment']),
                      trailing: Text(formattedDate),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Ваш комментарий',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
