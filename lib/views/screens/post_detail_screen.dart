// lib/views/screens/post_detail_screen.dart

import 'package:flutter/material.dart';
import '../../../models/post_model.dart';
import '../../models/weather_forecast.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../services/wordpress_service.dart';
import '../../views/screens/edit_post_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class PostDetailsScreen extends StatefulWidget {
  final int postId;
  final WeatherForecast? weatherForecast;

  const PostDetailsScreen({
    Key? key,
    required this.postId,
    this.weatherForecast,
  }) : super(key: key);

  @override
  _PostDetailsScreenState createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  WordPressService wordpressService = WordPressService();
  Post? post;
  bool _isLoading = true;
  List<String> _categoryNames = [];

  @override
  void initState() {
    super.initState();
    fetchPostDetails();
    fetchEventDetails();
  }


  Evento? evento;
  Future<void> fetchEventDetails() async {
    try {
      final headers = {
        'Authorization': wordpressService.getBasicAuthHeader(),
      };
      final url = Uri.parse('https://ia.digital.curitiba.br/wp-json/eventos-app/v1/evento/${widget.postId}');

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final eventoFetched = Evento.fromJson(data);
        setState(() {
          evento = eventoFetched;
        });
      } else {
        print('Falha ao buscar detalhes do evento: ${response.body}');
      }
    } catch (e) {
      print('Erro ao buscar detalhes do evento: $e');
    }
  }



  List<int> _categoryIds = [];
  Future<void> fetchPostDetails() async {
    try {
      final fetchedPost = await wordpressService.fetchPostById(widget.postId);
      if (fetchedPost != null) {
        // Fetch category names using the category IDs in the fetched post
        List<String> categoryNames = await wordpressService.fetchCategoryNames(fetchedPost.categories);
        _categoryIds = fetchedPost.categories;
        setState(() {
          post = fetchedPost;
          _categoryNames = categoryNames;
        });
        final videoUrl = extractVideoUrlFromContent(post!.content);
        if (videoUrl.isNotEmpty) {
          initializeVideoPlayer(videoUrl);
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      //print('Error fetching post details: $e');
    }
  }

  Future<void> initializeVideoPlayer(String videoUrl) async {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            autoPlay: true,
            looping: true,
          );
        });
      }).catchError((error) {
        if (!mounted) return;
        //print('Error initializing video player: $error');
        setState(() {
          _isLoading = false;
        });
      });
  }


  String extractVideoUrlFromContent(String content) {
    final regex = RegExp(r'src="([^"]+)"');
    final match = regex.firstMatch(content);
    return match?.group(1) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(post?.title ?? 'Loading...'),
        actions: <Widget>[
          if (widget.weatherForecast != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mostra a temperatura com uma casa decimal
                Text('${widget.weatherForecast?.temperature.toStringAsFixed(1)}°C'),
                // Adicionando espaço entre o texto da temperatura e o ícone
                const SizedBox(width: 8),
                // Ícone do clima baseado no código do ícone de weatherForecast
                if (widget.weatherForecast!.iconCode != null)
                  Image.network(
                    'https://openweathermap.org/img/wn/${widget.weatherForecast!.iconCode}@2x.png',
                    width: 40,
                  ),
                // Espaçamento no final
                const SizedBox(width: 16),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await fetchPostDetails();
              await fetchEventDetails();
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              if (post != null) {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditPostScreen(
                      post: post!,
                      weatherForecast: widget.weatherForecast,
                      categoryIds: _categoryIds.map((id) => id.toString()).toList(),
                    ),
                  ),
                );

                if (result == true) {
                  await fetchPostDetails();
                  await fetchEventDetails();
                }
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : buildPostDetails(),
    );
  }
  Widget buildPostDetails() {
    List<Widget> contentWidgets = [];

    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      contentWidgets.add(
        AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    if (post!.imageUrl != null) {
      contentWidgets.add(Image.network(post!.imageUrl!));
    }
    if (_categoryNames.isNotEmpty) {
      contentWidgets.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("${_categoryNames.join(", ")}"),
        ),
      );
    }
    contentWidgets.add(
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          DateFormat('dd MMMM, yyyy').format(post!.createdAt),
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );

    contentWidgets.add(
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Html(data: post!.content),
      ),
    );

    if (evento != null) {
      contentWidgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 20.0), // Alterado aqui
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Data e hora de Início
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.date_range),
                  Expanded(child: Text(' ${DateFormat('dd/MM/yyyy HH:mm').format(evento!.startDate)}')),
                ],
              ),
              const SizedBox(height: 10),
              // Data e hora de Fim
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.date_range),
                  Expanded(child: Text(' ${DateFormat('dd/MM/yyyy HH:mm').format(evento!.endDate)}')),
                ],
              ),
              const SizedBox(height: 10),
              // Localização
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.location_on),
                  Expanded(child: Text(' ${evento!.location}')),
                ],
              ),
              const SizedBox(height: 10),
              // Endereço
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.map),
                  Expanded(child: Text(' ${evento!.address}')),
                ],
              ),
              const SizedBox(height: 10),
              // Organizador
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.person),
                  Expanded(child: Text(' ${evento!.organizer}')),
                ],
              ),
            ],
          ),
        ),
      );
    }


    if (post?.evento != null) {
      contentWidgets.addAll([
        Text("Data de Início: ${DateFormat('dd/MM/yyyy').format(post!.evento!.startDate)}"),
        Text("Data de Fim: ${DateFormat('dd/MM/yyyy').format(post!.evento!.endDate)}"),
        Text("Localização: ${post!.evento!.location}"),
        Text("Endereço: ${post!.evento!.address}"),
        Text("Organizador: ${post!.evento!.organizer}"),
      ]);
    }
    return SingleChildScrollView(
      child: Column(children: contentWidgets),
    );
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
}
