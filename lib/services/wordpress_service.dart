// lib/services/wordpress_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/post_model.dart';

class WordPressService {
  final String _baseUrl = 'https://ia.digital.curitiba.br/wp-json/wp/v2';
  final String _eventEndpoint = 'https://ia.digital.curitiba.br/wp-json/eventos-app/v1/evento';
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  String getBasicAuthHeader() {
    final username = dotenv.env['WORDPRESS_USER'] ?? '';
    final password = dotenv.env['WORDPRESS_PASSWORD'] ?? '';
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<String?> getJwtToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<String?> loginUser(String username, String password) async {
    final url = Uri.parse(
        'https://ia.digital.curitiba.br/wp-json/jwt-auth/v1/token');
    final response = await http.post(
        url, body: {'username': username, 'password': password});
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final String? token = responseData['token'];
      if (token != null) {
        await saveToken(token); // Salva o token JWT
        return token;
      }
    }
    return null;
  }

  Future<bool> validateToken(String token) async {
    final url = Uri.parse(
        'https://ia.digital.curitiba.br//wp-json/jwt-auth/v1/token/validate');
    final response = await http.post(
        url, headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200;
  }

  Future<List<Post>> fetchPosts({int page = 1, int perPage = 10}) async {
    final Uri apiUrl = Uri.parse(
        '$_baseUrl/posts?_embed&page=$page&per_page=$perPage');
    try {
      final response = await http.get(apiUrl);
      if (response.statusCode == 200) {
        final List<dynamic> fetchedPosts = jsonDecode(response.body);
        return fetchedPosts.map((postData) => Post.fromJson(postData)).toList();
      } else {
        print(
            'Erro ao buscar posts: ${response.statusCode}. Mensagem: ${response
                .body}');
        return [];
      }
    } catch (e) {
      print('Exceção ao buscar posts: $e');
      return [];
    }
  }

  Future<bool> trashPost(int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId');
    final headers = {
      'Authorization': getBasicAuthHeader(),
      'Content-Type': 'application/json',
    };
    var body = jsonEncode({'status': 'trash'});
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      print('Post moved to trash successfully.');
      return true;
    } else {
      print('Failed to move the post to trash: ${response.body}');
      return false;
    }
  }

  Future<Evento?> fetchEventByPostId(int postId) async {
    final url = Uri.parse('$_eventEndpoint/$postId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Evento.fromJson(data);
    } else {
      print('Falha ao buscar detalhes do evento: ${response.body}');
      return null;
    }
  }

  Future<List<String>> fetchCategoryNames(List<int> categoryIds) async {
    List<String> categoryNames = [];
    for (var categoryId in categoryIds) {
      final url = Uri.parse('$_baseUrl/categories/$categoryId');
      try {
        final response = await http.get(url); // JWT is not used here
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          categoryNames.add(data['name']);
        } else {
          print('Falha ao buscar a categoria: ${response.body}');
        }
      } catch (e) {
        print('Exceção ao buscar a categoria: $e');
      }
    }
    return categoryNames;
  }

  Future<List<Post>> fetchPostsByCategory(String category) async {
    final apiUrl = '$_baseUrl/posts?_embed&categories=$category';
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return [];
    }

    try {
      final response = await http.get(
          Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final List<dynamic> fetchedPosts = jsonDecode(response.body);
        return fetchedPosts.map((postData) => Post.fromJson(postData)).toList();
      } else {
        print('Erro ao buscar posts por categoria: ${response
            .statusCode}. Mensagem: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exceção ao buscar posts por categoria: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchCategories() async {
    final url = Uri.parse('$_baseUrl/categories');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Falha ao carregar categorias: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exceção ao carregar categorias: $e');
      return [];
    }
  }

  Future<List<String>> fetchTagNames(List<int> tagIds) async {
    List<String> tagNames = [];
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return [];
    }

    for (var tagId in tagIds) {
      final url = Uri.parse('$_baseUrl/tags/$tagId');
      try {
        final response = await http.get(
            url, headers: {'Authorization': 'Bearer $token'});
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          tagNames.add(data['name']);
        } else {
          print('Falha ao buscar a tag: ${response.body}');
        }
      } catch (e) {
        print('Exceção ao buscar a tag: $e');
      }
    }

    return tagNames;
  }

  Future<Post?> fetchPostById(int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId?_embed');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Post.fromJson(data);
      } else {
        print('Falha ao buscar o post: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erro ao buscar detalhes do post: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadMedia(String mediaPath,
      {bool isVideo = false}) async {
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/media');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Disposition': 'attachment; filename="${basename(mediaPath)}"',
      'Content-Type': isVideo ? 'video/mp4' : 'image/jpeg',
    };

    var request = http.MultipartRequest('POST', url)
      ..headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath('file', mediaPath));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final responseBody = json.decode(response.body);
      return {
        'mediaId': responseBody['id'],
        'mediaUrl': responseBody['guid']['rendered']
      };
    } else {
      print('Falha ao fazer upload da mídia: ${response.body}');
      return null;
    }
  }

  Future<bool> createPost(String title,
      String content,
      String excerpt,
      int mediaId,
      String status,
      {String? videoUrl, List<
          int>? categoryIds, DateTime? startDate, DateTime? endDate, String? location, String? address, String? organizer}) async {
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return false;
    }

    final url = Uri.parse('$_baseUrl/posts');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    var bodyContent = content;
    if (videoUrl != null) {
      bodyContent +=
      '\n<!-- wp:video -->\n<video controls src="$videoUrl"></video>\n<!-- /wp:video -->';
    }
    List<int> safeCategoryIds = categoryIds ?? [];

    var body = jsonEncode({
      'title': title,
      'content': bodyContent,
      'excerpt': excerpt,
      'featured_media': mediaId,
      'status': status,
      'categories': safeCategoryIds,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 201) {
      final postId = json.decode(response.body)['id'];
      if (startDate != null && endDate != null && location != null &&
          address != null && organizer != null) {
        return await createOrUpdateEvent(postId: postId,
            startDate: startDate,
            endDate: endDate,
            location: location,
            address: address,
            organizer: organizer);
      }
      return true;
    } else {
      print('Falha ao criar o post: ${response.body}');
      return false;
    }
  }

  Future<bool> updateEvent({
    required int postId,
    required DateTime startDate,
    required DateTime endDate,
    required String location,
    required String address,
    required String organizer,
  }) async {
    // Correcting the URL to use a direct string if needed or ensuring Uri.parse is used correctly.
    final String eventUpdateUrl = '$_eventEndpoint/$postId'; // Make sure this URL is correct for your endpoint.
    final url = Uri.parse(eventUpdateUrl); // Ensuring Uri.parse is used to convert string URL to Uri.

    // Preparing the request headers to use Basic Authentication.
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': getBasicAuthHeader(),
    };

    // Encoding the request body as JSON.
    final body = jsonEncode({
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'location': location,
      'address': address,
      'organizer': organizer,
    });

    // Executing the POST request.
    final response = await http.post(url, headers: headers, body: body);

    // Checking the response status to determine success.
    if (response.statusCode == 200) {
      print('Event updated successfully.');
      return true;
    } else {
      print('Failed to update the event: ${response.body}');
      return false;
    }
  }

  Future<bool> createOrUpdateEvent({
    required int postId,
    required DateTime startDate,
    required DateTime endDate,
    required String location,
    required String address,
    required String organizer,
  }) async {
    final url = Uri.parse('$_eventEndpoint/$postId'); // Adjust the URL as needed.

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': getBasicAuthHeader(), // Use Basic Auth for authentication.
    };

    final body = jsonEncode({
      'post_id': postId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'location': location,
      'address': address,
      'organizer': organizer,
    });

    final response = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': getBasicAuthHeader(),
    }, body: body);

    if (response.statusCode == 200) {
      print('Evento criado ou atualizado com sucesso.');
      return true;
    } else {
      print('Falha ao criar ou atualizar o evento: ${response.body}');
      return false;
    }
  }

  Future<bool> deletePost(int postId) async {
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return false;
    }

    final url = Uri.parse('$_baseUrl/posts/$postId?_method=DELETE');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    final response = await http.post(url, headers: headers);

    if (response.statusCode == 200) {
      print('Post deletado com sucesso.');
      return true;
    } else {
      print('Falha ao deletar o post: ${response.body}');
      return false;
    }
  }

  Future<bool> updatePost({
    required int postId,
    required String title,
    required String content,
    List<int>? categoryIds,
    required String status,
  }) async {
    // Here we're assuming you're using Basic Auth. Adjust as needed for your auth setup.
    final headers = {
      'Authorization': getBasicAuthHeader(),
      'Content-Type': 'application/json',
    };

    List<int> safeCategoryIds = categoryIds ?? [];
    var body = jsonEncode({
      'title': title,
      'content': content,
      'categories': safeCategoryIds,
      'status': status,
    });

    final url = Uri.parse('$_baseUrl/posts/$postId');
    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      print('Post updated successfully.');
      return true;
    } else {
      print('Failed to update the post: ${response.body}');
      return false;
    }
  }
}
