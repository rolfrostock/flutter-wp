// lib/views/screens/post_form_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zefyrka/zefyrka.dart';
import '../../services/wordpress_service.dart';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import '../../views/screens/home_screen.dart';

class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key});

  @override
  _PostFormScreenState createState() => _PostFormScreenState();
}


class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  late ZefyrController _contentController;
  final TextEditingController _excerptController = TextEditingController();
  String? _postStatus = 'publish';
  XFile? _image;
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  final WordPressService _wordPressService = WordPressService();
  List<dynamic> _categories = [];
  List<String> _selectedCategoryIds = [];

  Future<void> _pickImageFromGallery() async {
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = pickedImage;
      _resetVideoController();
    });
  }

  Future<void> _captureImageWithCamera() async {
    final XFile? capturedImage = await _picker.pickImage(source: ImageSource.camera);
    setState(() {
      _image = capturedImage;
      _resetVideoController();
    });
  }

  Future<void> _pickVideoFromGallery() async {
    final XFile? pickedVideo = await _picker.pickVideo(source: ImageSource.gallery);
    setState(() {
      _image = pickedVideo;
      _initializeVideoController(pickedVideo!.path);
    });
  }

  Future<void> _captureVideoWithCamera() async {
    final XFile? capturedVideo = await _picker.pickVideo(source: ImageSource.camera);
    setState(() {
      _image = capturedVideo;
      _initializeVideoController(capturedVideo!.path);
    });
  }

  void _resetVideoController() {
    if (_videoController != null) {
      _videoController!.dispose();
      _videoController = null;
    }
  }

  void _initializeVideoController(String path) {
    _videoController?.dispose();

    _videoController = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void initState() {
    super.initState();
    _wordPressService.fetchCategories().then((categories) {
      setState(() {
        _categories = categories;
      });
    });
    _contentController = ZefyrController(NotusDocument());
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _showCategoryDialog() async {
    final allCategories = _categories;
    final Map<String, bool> categoryMap = {};
    for (var category in allCategories) {
      categoryMap[category['id'].toString()] = _selectedCategoryIds.contains(category['id'].toString());
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Adiciona um StatefulBuilder aqui
          builder: (context, setStateDialog) { // Agora usa setStateDialog para atualizar o estado do diálogo
            return AlertDialog(
              title: const Text("Select Categories"),
              content: SingleChildScrollView(
                child: ListBody(
                  children: allCategories.map<Widget>((category) {
                    return CheckboxListTile(
                      value: categoryMap[category['id'].toString()],
                      title: Text(category['name']),
                      onChanged: (bool? selected) {
                        setStateDialog(() { // Use setStateDialog para atualizar a UI do diálogo
                          categoryMap[category['id'].toString()] = selected!;
                        });
                        setState(() { // Use setState para atualizar a UI da página
                          if (selected == true) {
                            _selectedCategoryIds.add(category['id'].toString());
                          } else {
                            _selectedCategoryIds.remove(category['id'].toString());
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    bool isVideo = _image?.path.endsWith('.mp4') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Novo Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Visualização das Categorias Selecionadas
              Wrap(
                spacing: 8.0, // Espaço horizontal entre chips
                runSpacing: 4.0, // Espaço vertical entre chips
                children: _selectedCategoryIds.map((id) {
                  final categoryName = _categories.firstWhere(
                          (category) => category['id'].toString() == id,
                      orElse: () => {'name': 'Categoria não encontrada'}
                  )['name'];

                  return Chip(
                    label: Text(categoryName),
                    onDeleted: () {
                      setState(() {
                        _selectedCategoryIds.remove(id);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10), // Ajuste o padding conforme necessário
                child: GestureDetector(
                  onTap: () => _showCategoryDialog(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Centraliza o Row no eixo horizontal
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.blue), // Ícone
                      SizedBox(width: 10), // Espaçamento horizontal entre o ícone e o texto
                      Text("Categorias"), // Texto
                    ],
                  ),
                ),
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o título';
                  }
                  return null;
                },
              ),
              ZefyrToolbar.basic(controller: _contentController),
              Container(
                height: 300,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(width: 1.0, color: Colors.grey)),
                ),
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ZefyrEditor(
                  controller: _contentController,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  const Text('Status do Post: '),
                  DropdownButton<String>(
                    value: _postStatus,
                    onChanged: (String? newValue) {
                      setState(() {
                        _postStatus = newValue;
                      });
                    },
                    items: <String>['publish', 'draft']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: isVideo
                      ? _videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                      : Container()
                      : Image.file(File(_image!.path), height: 200),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: _pickImageFromGallery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.black),
                  ),
                  ElevatedButton(
                    onPressed: _captureImageWithCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.black),
                  ),

                  ElevatedButton(
                    onPressed: _pickVideoFromGallery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Icon(Icons.video_library, color: Colors.black),
                  ),

                  ElevatedButton(
                    onPressed: _captureVideoWithCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Icon(Icons.videocam, color: Colors.black),
                  ),

                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate() || _image == null) return;

                    final String contentPlainText = _contentController.document.toPlainText();
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) => const Dialog(
                        child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 20),
                              Text("Enviando..."),
                            ],
                          ),
                        ),
                      ),
                    );

                    final mimeType = lookupMimeType(_image!.path);
                    final isVideo = mimeType?.startsWith('video/') ?? false;
                    final mediaResponse = await _wordPressService.uploadMedia(_image!.path, isVideo: isVideo);

                    Navigator.pop(context);

                    if (mediaResponse != null && mounted) {
                      final int mediaId = mediaResponse['mediaId'];
                      final String? mediaUrl = mediaResponse['mediaUrl'];
                      final List<int> selectedCategoryIds = _selectedCategoryIds.map(int.parse).toList();

                      final bool success = await _wordPressService.createPost(
                        _titleController.text,
                        contentPlainText,
                        _excerptController.text,
                        mediaId,
                        _postStatus!,
                        videoUrl: isVideo ? mediaUrl : null,
                        categoryIds: selectedCategoryIds,
                      );

                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post criado com sucesso!')));
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                              (Route<dynamic> route) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao criar post')));
                      }

                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao fazer upload da mídia')));
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Enviar Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
