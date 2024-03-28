//lib/screens/home_screen/home_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/weather_forecast.dart';
import '../../models/post_model.dart';
import '../../views/screens/post_form_screen.dart';
import '../../views/screens/post_detail_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../services/wordpress_service.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../views/screens/login_screen.dart';


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
  List<Post> filteredPosts = [];
  WeatherForecast? weatherForecast;
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  final int postsPerPage = 3;
  TextEditingController _searchController = TextEditingController();
  List<Post> _searchResults = [];
  FocusNode _searchFocusNode = FocusNode();
  final String _baseUrl = 'https://ia.digital.curitiba.br/wp-json/wp/v2';
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

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _searchController.clear();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose(); // Não esqueça de dar dispose no FocusNode
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
      //print('API Key for OpenWeatherMap is not defined in .env file.');
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
        //print(
        //    'Failed to load weather data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      //print('Error fetching weather data: $e');
    }
  }

  Future<void> fetchPosts() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    final apiUrl = '$_baseUrl/posts?_embed&page=$currentPage&per_page=$postsPerPage';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> fetchedPosts = jsonDecode(response.body);
        if (fetchedPosts.isEmpty) {
          hasMore = false;
        } else {
          setState(() {
            posts.addAll(fetchedPosts.map((postData) => Post.fromJson(postData)).toList());
            currentPage++;
          });
        }
      } else {
        print('Erro ao buscar posts: ${response.statusCode}. Mensagem: ${response.body}');
      }
    } catch (e) {
      print('Exceção ao buscar posts: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void filterPosts(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredPosts = posts;
      });
    } else {
      setState(() {
        filteredPosts = posts.where((post) =>
            post.title.toLowerCase().contains(query.toLowerCase())).toList();
      });
    }
  }

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

  String stripHtmlIfNeeded(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: false);
    return htmlString.replaceAll(exp, '');
  }

  void _searchPosts(String query) async {

    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }
    if (query.length < 3) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    List<Post> tempResults = [];
    for (var post in posts) {
      bool containsInTitle = post.title.toLowerCase().contains(query.toLowerCase());

      List<String> categoryNames = await wordpressService.fetchCategoryNames(post.categories);
      bool containsInCategories = categoryNames.any((name) => name.toLowerCase().contains(query.toLowerCase()));

      if (containsInTitle || containsInCategories) {
        tempResults.add(post);
      }
    }

    setState(() {
      _searchResults = tempResults;
    });
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return FutureBuilder<List<String>>(
          future: wordpressService.fetchCategoryNames(post.categories),
          builder: (context, snapshot) {
            String categoryText = 'Carregando categorias...';
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              categoryText = 'Categorias: ${snapshot.data!.join(", ")}';
            }
            return ListTile(
              title: Text(post.title),
              subtitle: Text(categoryText, style: const TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => PostDetailsScreen(
                    postId: post.id,
                    weatherForecast: weatherForecast,
                  ),
                ));
              },
            );
          },
        );
      },
    );
  }

  Future<bool> searchInCategories(List<int> categoryIds, String query) async {
    List<String> categoryNames = await wordpressService.fetchCategoryNames(categoryIds);
    for (var categoryName in categoryNames) {
      if (categoryName.toLowerCase().contains(query.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    print('Construindo HomeScreen com ${posts.length} posts.');
    return Scaffold(
      appBar: AppBar(
        title: const Text('debernardo'),
        actions: [
          if (weatherForecast != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${weatherForecast!.temperature.toStringAsFixed(2)}°C'),
                if (weatherForecast!.iconCode != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Image.network('https://openweathermap.org/img/wn/${weatherForecast!.iconCode}@2x.png', width: 40),
                  ),
                const SizedBox(width: 16), // For spacing
              ],
            ),
          ],
          IconButton(
            icon: Icon(Icons.login),
            onPressed: () async {
              // Navega para a tela de login
              final username = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );

              // Opcional: Faça algo com o nome de usuário retornado, como exibir um SnackBar
              if (username != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Bem-vindo, $username!')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              currentPage = 1;
              posts.clear();
              await fetchPosts();
              await fetchWeatherData();
              _searchController.clear();
              setState(() {
                _searchResults.clear();
                filteredPosts = List.from(posts);
              });

              _searchFocusNode.unfocus();
            },
          ),

          IconButton(
            icon: Icon(Icons.brightness_4),
            onPressed: () {
              final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
              themeProvider.toggleTheme(themeProvider.currentTheme.brightness == Brightness.dark ? false : true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              focusNode: _searchFocusNode,
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '#...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              onChanged: _searchPosts,
            ),
          ),
          Expanded(
            child: _searchResults.isNotEmpty
                ? _buildSearchResults()
                : Padding(
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
          ),
        ],
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
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
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
    final videoUrl = extractVideoUrlFromContent(post.content);

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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                post.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20.0, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _confirmDeletePost(context, post.id),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: IconButton(
                        icon: Icon(Icons.read_more, size: _iconSize),
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
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 50.0, top:40.0),
              child: Text(
                limitWords(stripHtmlIfNeeded(post.content), 30),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (post.evento != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evento: ${DateFormat('dd/MM/yyyy').format(post.evento!.startDate)} até ${DateFormat('dd/MM/yyyy').format(post.evento!.endDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Localização: ${post.evento!.location}'),
                    Text('Endereço: ${post.evento!.address}'),
                    Text('Organizador: ${post.evento!.organizer}'),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 50.0, top:8.0),
              child: Text(
                DateFormat('dd MMMM, yyyy').format(post.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

double _iconSize = 32.0;

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
class PostDetailScreen extends StatefulWidget {
  final int postId;

  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Future<Post?> postFuture;

  @override
  void initState() {
    super.initState();
    postFuture = WordPressService().fetchPostById(widget.postId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Post'),
      ),
      body: FutureBuilder<Post?>(
        future: postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar detalhes do post: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final post = snapshot.data;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post?.imageUrl != null)
                      Image.network(post!.imageUrl!),
                    Text(post?.title ?? 'Título não disponível', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    Text(post?.content ?? 'Conteúdo não disponível'),
                  ],
                ),
              ),
            );
          } else {
            return const Center(child: Text('Dados do post não disponíveis.'));
          }
        },
      ),
    );
  }
}
