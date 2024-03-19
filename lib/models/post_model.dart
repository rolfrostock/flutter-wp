//lib/models/post_model.dart

class Post {
  final int id;
  final String title;
  final String content;
  final String excerpt;
  final DateTime createdAt;
  final String? imageUrl;
  final List<int> categories;
  final List<int> tags;
  final String? videoUrl;
  final String? featuredMediaUrl;
  final String? thumbnailUrl;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.createdAt,
    this.imageUrl,
    this.categories = const [],
    this.tags = const [],
    this.videoUrl,
    this.featuredMediaUrl,
    this.thumbnailUrl,
  });


  factory Post.fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    try {
      imageUrl =
      json['_embedded']['wp:featuredmedia'][0]['source_url'] as String;
    } catch (e) {
      imageUrl = null; // Define como nulo se a imagem não estiver disponível
    }

    String? videoUrl = json['video_url'] as String?;

    return Post(
      id: json['id'],
      title: json['title']['rendered'],
      content: json['content']['rendered'],
      excerpt: json['excerpt']['rendered'],
      createdAt: DateTime.parse(json['date']),
      imageUrl: imageUrl,
      // Utiliza a variável local que armazena a URL da imagem ou nulo
      categories: List<int>.from(json['categories'] ?? []),
      tags: List<int>.from(json['tags'] ?? []),
      videoUrl: videoUrl, // Utiliza a variável local videoUrl, que pode ser nula
      // O campo featuredMediaUrl não está sendo preenchido neste código; ajuste conforme necessário
    );
  }
}
