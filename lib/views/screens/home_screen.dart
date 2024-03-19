//lib/screens/home_screen/home_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/weather_forecast.dart';
import '../../models/post_model.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../views/screens/post_form_screen.dart';
import '../../views/screens/post_detail_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../services/wordpress_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class CustomCacheManager {
  static const key = "customCacheKey";

  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 15),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

class _HomeScreenState extends State<HomeScreen> {
  final WordPressService wordpressService = WordPressService();
  final PageController _pageController = PageController(viewportFraction: 1.0);
  List<Post> posts = [];
  WeatherForecast? weatherForecast;
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  final int postsPerPage = 3;
  //final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _pageController.addListener(() {
      if (_pageController.page == posts.length - 2 && !isLoading && hasMore) {
        fetchPosts();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await dotenv.load();
    fetchWeatherData();
    fetchPosts();
  }

  Future<void> fetchWeatherData() async {
    final apiKey = dotenv.env['OPENWEATHERMAP_API_KEY'];
    if (apiKey == null) {
      print('API Key for OpenWeatherMap is not defined in .env file.');
      return;
    }
    final weatherUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=Curitiba&appid=$apiKey&units=metric');
    try {
      final response = await http.get(weatherUrl);
      if (response.statusCode == 200) {
        final WeatherForecast forecast =
        WeatherForecast.fromJson(jsonDecode(response.body));
        setState(() {
          weatherForecast = forecast;
        });
      } else {
        print(
            'Failed to load weather data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching weather data: $e');
    }
  }

  Future<void> fetchPosts() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    final apiUrl =
        'https://ia.digital.curitiba.br/wp-json/wp/v2/posts?_embed&page=$currentPage&per_page=$postsPerPage';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      final List<dynamic> fetchedPosts = jsonDecode(response.body);
      if (fetchedPosts.isEmpty) {
        hasMore = false;
      } else {
        if (!mounted) return;
        setState(() {
          posts.addAll(
              fetchedPosts.map((postData) => Post.fromJson(postData)).toList());
          currentPage++;
        });
      }
    } catch (e) {
      // Tratar erro adequadamente...
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

//  void _loadMorePosts() {
//    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent && !isLoading) {
//      fetchPosts();
//    }
//  }

  void _confirmDeletePost(BuildContext context, int postId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Deletar Post"),
          content: const Text("Você tem certeza que deseja deletar este post?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Deletar"),
              onPressed: () {
                _deletePost(postId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deletePost(int postId) async {
    final success = await wordpressService.deletePost(postId);
    if (success) {
      if (!mounted) return;
      setState(() {
        posts.removeWhere((post) => post.id == postId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deletado com sucesso!')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao deletar post.')));
    }
  }

  Future<FileInfo> getCachedFile(String url) async {
    FileInfo? cachedFile =
    await CustomCacheManager.instance.getFileFromCache(url);
    if (cachedFile != null) {
      return cachedFile;
    } else {
      FileInfo fileInfo = await CustomCacheManager.instance.downloadFile(url);
      return fileInfo;
    }
  }

  String removeHoverFromHtml(String htmlContent) {
    return htmlContent.replaceAll(RegExp(':hover'), '');
  }

  String limitWords(String text, int wordLimit) {
    var words = text.split(RegExp('\\s+'));
    if (words.length > wordLimit) {
      return '${words.take(wordLimit).join(' ')}...';
    }
    return text;
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
        title: const Text('ia.digital.curitiba.br'),
        actions: [
          if (weatherForecast != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.wb_sunny),
                  const SizedBox(width: 8),
                  Text('${weatherForecast!.temperature.toStringAsFixed(2)}°C'),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              currentPage = 1;
              posts.clear();
              await fetchPosts();
              await fetchWeatherData();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 50),
        child: PageView.builder(
          controller: _pageController,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return buildPostCard(post);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool? isPostCreated = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PostFormScreen(),
              fullscreenDialog: true,
            ),
          );
          if (isPostCreated ?? false) {
            fetchPosts();
          }
        },
        tooltip: 'Criar novo post',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget buildPostsList() {
    return PageView.builder(
      controller: PageController(viewportFraction: 1.0),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return buildPostCard(post);
      },
    );
  }

  Widget buildPostCard(Post post) {
    // Extrai a URL do vídeo do conteúdo do post
    final videoUrl = extractVideoUrlFromContent(post.content);
    final contentPreview = _limitWords(post.content, 30);

    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (post.imageUrl != null)
              Image.network(
                post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                post.title,
                style: const TextStyle(
                    fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                DateFormat('dd MMMM, yyyy').format(post.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            FutureBuilder<List<String>>(
              future: wordpressService.fetchCategoryNames(post.categories),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(snapshot.data!.join(', ')),
                  );
                } else {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Carregando categorias..."),
                  );
                }
              },
            ),
            if (videoUrl.isNotEmpty)
              FutureBuilder<FileInfo>(
                future: getCachedFile(videoUrl),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    return AspectRatio(
                      aspectRatio: 16 / 9,
                      child: VideoPlayerWidget(videoFile: snapshot.data!.file),
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Html(data: post.excerpt),
            ),
            // Aqui você adiciona o texto resumido
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(contentPreview),
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: 20.0,
                top: 20.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      // Implemente a lógica de compartilhamento aqui
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _confirmDeletePost(context, post.id),
                  ),
                  TextButton(
                    child: const Text("Ler mais...",
                        style: TextStyle(color: Colors.blue)),
                    onPressed: () {
                      if (weatherForecast != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailsScreen(
                              postId: post.id,
                              weatherForecast: weatherForecast!,
                            ),
                          ),
                        );
                      } else {
                        // Opcional: Mostrar uma mensagem de erro ou feedback ao usuário
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _limitWords(String text, int wordLimit) {
  var words = text.split(RegExp('\\s+'));
  if (words.length > wordLimit) {
    return '${words.take(wordLimit).join(' ')}...';
  }
  return text;
}

class VideoPlayerWidget extends StatefulWidget {
  final File videoFile;

  const VideoPlayerWidget({super.key, required this.videoFile});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController,
            aspectRatio: _videoPlayerController.value.aspectRatio,
            autoPlay: false,
            looping: true,
          );
        });
      });
  }

  @override
  Widget build(BuildContext context) {
    return _videoPlayerController.value.isInitialized
        ? AspectRatio(
      aspectRatio: _videoPlayerController.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    )
        : const Center(child: CircularProgressIndicator());
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
}
