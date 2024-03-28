//lib/models/post_model.dart

import 'dart:convert';


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
  final Evento? evento;
  final String? status;

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
    this.evento,
    this.status,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    try {
      imageUrl = json['_embedded']['wp:featuredmedia'][0]['source_url'] as String?;
    } catch (e) {
      imageUrl = null;
    }

    String? videoUrl = json['video_url'] as String?;
    Evento? evento;

    if (json['evento'] != null) {
      evento = Evento.fromJson(json['evento']);
    }

    // Include status in the Post creation
    return Post(
      id: json['id'],
      title: json['title']['rendered'],
      content: json['content']['rendered'],
      excerpt: json['excerpt']['rendered'],
      createdAt: DateTime.parse(json['date']),
      imageUrl: imageUrl,
      categories: List<int>.from(json['categories'] ?? []),
      tags: List<int>.from(json['tags'] ?? []),
      videoUrl: videoUrl,
      featuredMediaUrl: null,
      thumbnailUrl: null,
      evento: evento,
      status: json['status'], // Extract status from JSON
    );
  }
}


Evento eventoFromJson(String str) => Evento.fromJson(json.decode(str));

class Evento {
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final String address;
  final String organizer;

  Evento({
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.address,
    required this.organizer,
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      location: json['location'],
      address: json['address'],
      organizer: json['organizer'],
    );
  }

  get date => null;

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'location': location,
      'address': address,
      'organizer': organizer,
    };
  }
}



