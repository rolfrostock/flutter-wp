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

class PostDetailsScreen extends StatefulWidget {
  final int postId;
  final WeatherForecast? weatherForecast;

  const PostDetailsScreen({
    super.key,
    required this.postId,
    this.weatherForecast,
  });

  @override
  _PostDetailsScreenState createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  WordPressService wordpressService = WordPressService();
  Post? post;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPostDetails();
  }

  Future<void> fetchPostDetails() async {
    try {
      final fetchedPost = await wordpressService.fetchPostById(widget.postId);
      if (fetchedPost != null) {
        setState(() {
          post = fetchedPost;
        });
        final videoUrl = extractVideoUrlFromContent(post!.content);
        if (videoUrl.isNotEmpty) {
          initializeVideoPlayer(videoUrl);
        } else {
          // Se não houver vídeo, marca como não carregando
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching post details: $e');
    }
  }

  Future<void> initializeVideoPlayer(String videoUrl) async {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();

    // Substitua VideoPlayerController.network por VideoPlayerController.networkUrl
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
        print('Error initializing video player: $error');
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
          // Only display the weather info if weatherForecast is not null
          if (widget.weatherForecast != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.wb_sunny),
                  const SizedBox(width: 8),
                  Text('${widget.weatherForecast?.temperature.toStringAsFixed(1)}°C'),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchPostDetails,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              if (post != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditPostScreen(
                      post: post!,
                      weatherForecast: widget.weatherForecast,
                    ),
                  ),
                ).then((value) {
                  // Refresh post details after potentially editing the post
                  fetchPostDetails();
                });
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
