// lib/services/journal_api_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import '../models/post_model.dart'; // Atualize com o caminho correto do seu modelo Post

class WordPressService {
  // Endpoint da API do WordPress
  final String _baseUrl = 'https://ia.digital.curitiba.br/wp-json/wp/v2';

  // Método para buscar os nomes das categorias
  Future<List<String>> fetchCategoryNames(List<int> categoryIds) async {
    List<String> categoryNames = [];
    for (var categoryId in categoryIds) {
      final url = Uri.parse('$_baseUrl/categories/$categoryId');
      final response = await http.get(url, headers: {'Authorization': _getBasicAuthHeader()});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        categoryNames.add(data['name']);
      } else {
        print('Falha ao buscar a categoria: ${response.body}');
      }
    }
    return categoryNames;
  }

  Future<List<dynamic>> fetchCategories() async {
    final url = Uri.parse('$_baseUrl/categories');
    final response = await http.get(url, headers: {'Authorization': _getBasicAuthHeader()});
    if (response.statusCode == 200) {
      List<dynamic> categories = json.decode(response.body);
      return categories;
    } else {
      throw Exception('Failed to load categories');
    }
  }


  // Método para buscar os nomes das tags
  Future<List<String>> fetchTagNames(List<int> tagIds) async {
    List<String> tagNames = [];
    for (var tagId in tagIds) {
      final url = Uri.parse('$_baseUrl/tags/$tagId');
      final response = await http.get(url, headers: {'Authorization': _getBasicAuthHeader()});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        tagNames.add(data['name']);
      } else {
        print('Falha ao buscar a tag: ${response.body}');
      }
    }
    return tagNames;
  }

  // Método para buscar o conteúdo de um post pelo ID
  Future<Post?> fetchPostById(int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId?_embed');
    final response = await http.get(url, headers: {'Authorization': _getBasicAuthHeader()});

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Post.fromJson(data); // Substitua pelo método de construção do seu modelo Post
    } else {
      print('Falha ao buscar o post: ${response.body}');
      return null;
    }
  }

  // Carrega as credenciais do arquivo .env
  String _getBasicAuthHeader() {
    final username = dotenv.env['WORDPRESS_USER'] ?? '';
    final password = dotenv.env['WORDPRESS_PASSWORD'] ?? '';
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  // Modificado para retornar tanto o ID da mídia quanto o URL da mesma
  Future<Map<String, dynamic>?> uploadMedia(String mediaPath, {bool isVideo = false}) async {
    final url = Uri.parse('$_baseUrl/media');
    final headers = {
      'Authorization': _getBasicAuthHeader(),
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
      // Agora retorna um Map contendo o ID e o URL da mídia carregada
      return {
        'mediaId': responseBody['id'],
        'mediaUrl': responseBody['guid']['rendered'] // Ajuste conforme a estrutura da sua resposta
      };
    } else {
      print('Falha ao fazer upload da mídia: ${response.body}');
      return null;
    }
  }

  // Adiciona um argumento opcional para URL do vídeo e ajusta o conteúdo do post para incluir o vídeo, se fornecido
  Future<bool> createPost(
      String title,
      String content,
      String excerpt,
      int mediaId,
      String status,
      {String? videoUrl, List<int>? categoryIds} // Modificado para aceitar uma lista de categorias
      ) async {
    final url = Uri.parse('$_baseUrl/posts');
    final headers = {
      'Authorization': _getBasicAuthHeader(),
      'Content-Type': 'application/json',
    };

    var bodyContent = content;
    if (videoUrl != null) {
      bodyContent += '\n<!-- wp:video -->\n<video controls src="$videoUrl"></video>\n<!-- /wp:video -->';
    }

    var body = jsonEncode({
      'title': title,
      'content': bodyContent,
      'excerpt': excerpt,
      'featured_media': mediaId,
      'status': status,
      'categories': categoryIds ?? [], // Correção aqui
    });

    final response = await http.post(url, headers: headers, body: body);

    return response.statusCode == 201; // Retorna 'true' se o status code for 201, indicando sucesso
  }

  Future<Map<String, dynamic>?> fetchPostContent(int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId');
    final headers = {'Authorization': _getBasicAuthHeader()};

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      // Converte a resposta da API de String JSON para um Map
      final Map<String, dynamic> postData = json.decode(response.body);
      return postData;
    } else {
      print('Falha ao buscar o post: ${response.body}');
      return null;
    }
  }

  Future<bool> deletePost(int postId) async {
    final url = Uri.parse('$_baseUrl/posts/$postId?_method=DELETE');
    final response = await http.post(
      url,
      headers: {
        'Authorization': _getBasicAuthHeader(),
        // Outros cabeçalhos necessários
      },
    );

    if (response.statusCode == 200) {
      // Post deletado com sucesso
      return true;
    } else {
      // Falha ao deletar o post
      return false;
    }
  }

  Future<bool> updatePost(int postId, String title, String content, String excerpt) async {
    final url = Uri.parse('$_baseUrl/posts/$postId');
    final headers = {
      'Authorization': _getBasicAuthHeader(),
      'Content-Type': 'application/json',
    };

    var body = jsonEncode({
      'title': title,
      'content': content,
      'excerpt': excerpt,
    });

    final response = await http.post(url, headers: headers, body: body); // Ou http.put, conforme sua API

    return response.statusCode == 200; // Ou outro código de sucesso esperado
  }
}