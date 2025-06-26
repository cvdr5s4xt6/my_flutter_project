import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_giftbox_app/pages/review.comments.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'user_provider.dart';

class ReviewsPage extends StatefulWidget {
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  late final SupabaseClient supabase;
  Future<List<Map<String, dynamic>>>? _futureReviews;
  String? userId;
  File? _pickedImage;
  final _commentController = TextEditingController();

  // TODO: Замените на реальный order_id из вашего приложения
  int? _currentOrderId = 1;

  @override
  void initState() {
    super.initState();
    supabase = Supabase.instance.client;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userId = userProvider.userId;
    if (userId != null) {
      _futureReviews = _loadReviews(userId!);
    } else {
      print('Ошибка: userId не найден.');
    }
  }

  Future<List<Map<String, dynamic>>> _loadReviews(String userId) async {
    try {
      final data = await supabase.rpc(
        'get_reviews_with_meta',
        params: {'user_id': userId},
      );
      final sliced = (data as List<dynamic>)
          .take(10)
          .cast<Map<String, dynamic>>()
          .toList();
      return sliced;
    } catch (e) {
      print('Ошибка загрузки отзывов: $e');
      return [];
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  Future<void> _submitReview() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    if (_currentOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не задан order_id для отзыва')),
      );
      return;
    }

    String? photoUrl;

    try {
      if (_pickedImage != null) {
        final fileBytes = await _pickedImage!.readAsBytes();
        final filePath = 'reviews/$userId/${const Uuid().v4()}.jpg';

        // Загружаем в хранилище, uploadBinary возвращает путь (String)
        final String uploadedPath = await supabase.storage
            .from('order-reviews')
            .uploadBinary(filePath, fileBytes);

        // Получаем публичный URL по пути
        photoUrl = supabase.storage
            .from('order-reviews')
            .getPublicUrl(uploadedPath);
      }

      final insertRes = await supabase.from('reviews').insert({
        'user_id': userId,
        'order_id': _currentOrderId,
        'comment': text,
        'photo_url': photoUrl,
      }).select();

      if (insertRes == null || (insertRes is List && insertRes.isEmpty)) {
        throw Exception('Ошибка добавления отзыва: пустой ответ');
      }

      _commentController.clear();
      setState(() {
        _pickedImage = null;
        _futureReviews = _loadReviews(userId!);
      });
    } catch (e) {
      print('Ошибка при отправке отзыва: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Отзывы')),
        body: const Center(child: Text('Ошибка: пользователь не авторизован')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Отзывы')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(hintText: 'Ваш отзыв'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _submitReview,
                ),
              ],
            ),
          ),
          if (_pickedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Image.file(_pickedImage!, height: 100),
            ),
          Expanded(
            child: _futureReviews == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _futureReviews,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(child: Text('Ошибка: ${snap.error}'));
                      }
                      if (!snap.hasData || snap.data!.isEmpty) {
                        return const Center(child: Text('Нет отзывов.'));
                      }

                      final reviews = snap.data!;
                      return ListView.builder(
                        itemCount: reviews.length,
                        itemBuilder: (_, i) {
                          final r = reviews[i];
                          final likedByMe = (r['user_liked'] as bool?) ?? false;

                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r['first_name']} ${r['last_name']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (r['photo_url'] != null &&
                                      r['photo_url'].toString().isNotEmpty)
                                    CachedNetworkImage(
                                      imageUrl: r['photo_url'],
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) =>
                                          const CircularProgressIndicator(),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.broken_image),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(r['comment'] ?? ''),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          likedByMe
                                              ? Icons.thumb_up
                                              : Icons.thumb_up_outlined,
                                        ),
                                        color: likedByMe ? Colors.blue : null,
                                        onPressed: () async {
                                          await _toggleLike(
                                            r['review_id'],
                                            likedByMe,
                                            userId!,
                                          );
                                        },
                                      ),
                                      Text('${r['likes_count'] ?? 0}'),
                                      const Spacer(),
                                      TextButton(
                                        child: Text(
                                          'Комментариев: ${r['comments_count'] ?? 0}',
                                        ),
                                        onPressed: () async {
                                          final updated =
                                              await Navigator.push<bool>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ReviewCommentsPage(
                                                        reviewId:
                                                            r['review_id'],
                                                      ),
                                                ),
                                              );
                                          if (updated == true) {
                                            setState(() {
                                              _futureReviews = _loadReviews(
                                                userId!,
                                              );
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(int reviewId, bool liked, String userId) async {
    try {
      if (liked) {
        await supabase.from('review_likes').delete().match({
          'review_id': reviewId,
          'user_id': userId,
        });
      } else {
        await supabase.from('review_likes').insert({
          'review_id': reviewId,
          'user_id': userId,
        });
      }

      setState(() {
        _futureReviews = _loadReviews(userId);
      });
    } catch (e) {
      print('Ошибка при переключении лайка: $e');
    }
  }
}
