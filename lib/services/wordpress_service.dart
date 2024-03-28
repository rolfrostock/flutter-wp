// lib/services/wordpreess_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/post_model.dart'; // Substitua por seus próprios modelos

class WordPressService {
  final String _baseUrl = 'https://ia.digital.curitiba.br/wp-json/wp/v2';
  final String _eventEndpoint = 'https://ia.digital.curitiba.br/wp-json/eventos-app/v1/evento';
  final _storage = FlutterSecureStorage();

  String getBasicAuthHeader() {
    final username = dotenv.env['WORDPRESS_USER'] ?? '';
    final password = dotenv.env['WORDPRESS_PASSWORD'] ?? '';
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
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

  Future<String?> getJwtToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<String?> loginUser(String username, String password) async {
    final url = Uri.parse('https://ia.digital.curitiba.br/wp-json/jwt-auth/v1/token');
    final response = await http.post(url, body: {'username': username, 'password': password});
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['token'];
    } else {
      return null;
    }
  }

  Future<String> getAuthHeader() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      throw Exception('JWT Token not found');
    }
    return 'Bearer $token';
  }


  Future<bool> validateToken(String token) async {
    final url = Uri.parse('https://ia.digital.curitiba.br//wp-json/jwt-auth/v1/token/validate');
    final response = await http.post(url, headers: {'Authorization': 'Bearer $token'});
    return response.statusCode == 200;
  }

  Future<Evento?> fetchEventByPostId(int postId, String token) async {
    final url = Uri.parse('https://ia.digital.curitiba.br/wp-json/api/v1/$postId');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Evento.fromJson(data);
    } else {
      print('Falha ao buscar detalhes do evento: ${response.body}');
      return null;
    }
  }


  Future<String?> getToken() async {
    try {
      return await _storage.read(key: 'jwt_token');
    } catch (e) {
      print("Erro ao obter o token: $e");
      return null;
    }
  }

  Future<List<String>> fetchCategoryNames(List<int> categoryIds) async {
    List<String> categoryNames = [];

    // Obter o token JWT armazenado de forma segura
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return []; // Retorna lista vazia ou trata como necessário
    }

    for (var categoryId in categoryIds) {
      final url = Uri.parse('$_baseUrl/categories/$categoryId');

      try {
        // Realiza a requisição GET com o cabeçalho de autorização Bearer
        final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

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



  Future<List<Post>> fetchPosts(int page, int perPage) async {
    final apiUrl = '$_baseUrl/posts?_embed&page=$page&per_page=$perPage';

    // Obtém o token JWT armazenado de forma segura
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return []; // Retorna lista vazia ou trata como necessário
    }

    try {
      // Realiza a requisição GET com o cabeçalho de autorização Bearer
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetchedPosts = jsonDecode(response.body);
        return fetchedPosts.map((postData) => Post.fromJson(postData)).toList();
      } else {
        print('Erro ao buscar posts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exceção ao buscar posts: $e');
      return [];
    }
  }



  Future<List<Post>> fetchPostsByCategory(String category) async {
    final apiUrl = '$_baseUrl/posts?_embed&categories=$category';

    // Obtém o token JWT armazenado de forma segura
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return []; // Retorna lista vazia ou trata como necessário
    }

    try {
      // Realiza a requisição GET com o cabeçalho de autorização Bearer
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetchedPosts = jsonDecode(response.body);
        return fetchedPosts.map((postData) => Post.fromJson(postData)).toList();
      } else {
        print('Erro ao buscar posts por categoria: ${response.statusCode}. Mensagem: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exceção ao buscar posts por categoria: $e');
      return [];
    }
  }


  Future<bool> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/jwt-auth/v1/token'); // Ajuste para o seu endpoint correto
    final response = await http.post(
      url,
      body: {
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      // Armazene o token JWT para futuras requisições
      // Exemplo: sharedPreferences.setString('jwt_token', responseBody['token']);
      return true;
    } else {
      return false;
    }
  }

  Future<void> fetchProtectedData() async {
    // Obter o token JWT armazenado de forma segura
    final token = await _storage.read(key: 'jwt_token');

    // Verificar se o token existe
    if (token != null) {
      final url = Uri.parse('https://ia.digital.curitiba.br/wp-json/wp/v2/posts');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        // Processar os dados recebidos
        print("Dados recebidos com sucesso.");
      } else {
        // Tratar erro
        print("Erro ao acessar os dados protegidos. StatusCode: ${response.statusCode}");
      }
    } else {
      print("Token JWT não encontrado.");
    }
  }



  Future<List<dynamic>> fetchCategories() async {
    // Obter o token JWT armazenado de forma segura
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return []; // Retorna lista vazia ou lança uma exceção conforme a necessidade do seu aplicativo
    }

    final url = Uri.parse('$_baseUrl/categories');

    // Modifica o cabeçalho para usar o token JWT
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token', // Usa o esquema Bearer aqui
    });

    if (response.statusCode == 200) {
      List<dynamic> categories = json.decode(response.body);
      return categories;
    } else {
      print('Falha ao carregar categorias: ${response.body}');
      return []; // Pode optar por retornar lista vazia ou lançar uma exceção
    }
  }


  Future<List<String>> fetchTagNames(List<int> tagIds) async {
    List<String> tagNames = [];

    // Obter o token JWT armazenado de forma segura
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return tagNames; // Retorna lista vazia ou trata como necessário
    }

    for (var tagId in tagIds) {
      final url = Uri.parse('$_baseUrl/tags/$tagId');

      // Modifica o cabeçalho para usar o token JWT
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token', // Usa o esquema Bearer aqui
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        tagNames.add(data['name']);
      } else {
        print('Falha ao buscar a tag: ${response.body}');
      }
    }

    return tagNames;
  }


  Future<Post?> fetchPostById(int postId) async {
    // Obter o token JWT armazenado de forma segura
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return null; // Retorna null ou trata como necessário
    }

    final url = Uri.parse('$_baseUrl/posts/$postId?_embed');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Post.fromJson(data);
    } else {
      print('Falha ao buscar o post: ${response.body}');
      return null;
    }
  }


  Future<Map<String, dynamic>?> uploadMedia(String mediaPath, {bool isVideo = false}) async {
    // Obter o token JWT armazenado de forma segura
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return null; // Retorna null ou trata como necessário
    }

    final url = Uri.parse('$_baseUrl/media');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Disposition': 'attachment; filename="${basename(mediaPath)}"',
      'Content-Type': isVideo ? 'video/mp4' : 'image/jpeg',
    };

    var request = http.MultipartRequest('POST', url)
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('file', mediaPath));

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


  Future<bool> createPost(
      String title,
      String content,
      String excerpt,
      int mediaId,
      String status,
      {String? videoUrl, List<int>? categoryIds, DateTime? startDate, DateTime? endDate, String? location, String? address, String? organizer}) async {
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return false; // Retorna false ou trata como necessário
    }

    final url = Uri.parse('$_baseUrl/posts');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    var bodyContent = content;
    if (videoUrl != null) {
      bodyContent += '\n<!-- wp:video -->\n<video controls src="$videoUrl"></video>\n<!-- /wp:video -->';
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
      if (startDate != null && endDate != null && location != null && address != null && organizer != null) {
        return await createOrUpdateEvent(postId: postId, startDate: startDate, endDate: endDate, location: location, address: address, organizer: organizer);
      }
      return true;
    } else {
      print('Falha ao criar o post: ${response.body}');
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
    final url = Uri.parse(_eventEndpoint);
    final authHeader = getBasicAuthHeader(); // Utiliza autenticação Basic

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
      'Authorization': authHeader, // Utiliza autenticação Basic
    }, body: body);

    if (response.statusCode == 200) {
      print('Evento criado ou atualizado com sucesso.');
      return true;
    } else {
      print('Falha ao criar ou atualizar o evento: ${response.body}');
      return false;
    }
  }

  Future<Evento?> fetchEventDetails(int postId) async {
    final url = Uri.parse('$_eventEndpoint/$postId');
    final headers = {'Authorization': getBasicAuthHeader()}; // Utiliza autenticação Basic

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Evento.fromJson(data);
    } else {
      print('Falha ao buscar detalhes do evento: ${response.body}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchPostContent(int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId');
    final headers = {'Authorization': getBasicAuthHeader()};

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final Map<String, dynamic> decodedJson = jsonDecode(response.body);
      final List<dynamic> fetchedPosts = decodedJson['posts'];
    } else {
      print('Falha ao buscar o post: ${response.body}');
      return null;
    }
  }

  Future<bool> deletePost(int postId) async {
    // Obter o token JWT armazenado de forma segura
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return false; // Retorna false ou trata como necessário
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

  Future<bool> updateEvent({
    required int postId,
    required DateTime startDate,
    required DateTime endDate,
    required String location,
    required String address,
    required String organizer,
  }) async {
    final url = Uri.parse('$_eventEndpoint');

    // Sempre usa a autenticação Basic aqui
    final authHeader = getBasicAuthHeader();

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
      'Authorization': authHeader, // Utiliza autenticação Basic
    }, body: body);

    if (response.statusCode == 200) {
      print('Evento criado ou atualizado com sucesso.');
      return true;
    } else {
      print('Falha ao criar ou atualizar o evento: ${response.body}');
      return false;
    }
  }

  Future<bool> updatePost({
    required int postId,
    required String title,
    required String content,
    required List<int> categoryIds,
    required String status,
  }) async {
    final token = await getJwtToken();
    if (token == null) {
      print('Token JWT não encontrado.');
      return false; // Retorna false ou trata como necessário
    }

    final url = Uri.parse('$_baseUrl/posts/$postId');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };


    List<String> categoryIdsAsString = categoryIds.map((id) => id.toString()).toList();
    var body = jsonEncode({
      'title': title,
      'content': content,
      'categories': categoryIdsAsString,
      'status': status,
    });

    final response = await http.post(url, headers: headers, body: body);
    return response.statusCode == 200;
  }



}