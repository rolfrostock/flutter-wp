// pos_form_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zefyrka/zefyrka.dart';
import '../../services/wordpress_service.dart';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import '../../views/screens/post_detail_screen.dart';
import 'package:intl/intl.dart';


class PostFormScreen extends StatefulWidget {
  const PostFormScreen({Key? key}) : super(key: key);

  @override
  _PostFormScreenState createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _excerptController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _organizerController = TextEditingController();
  late ZefyrController _contentController;
  String? _postStatus = 'publish';
  XFile? _image;
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  final WordPressService _wordPressService = WordPressService();
  DateTime? _startDate;
  DateTime? _endDate;
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
      _titleController.dispose();
      _contentController.dispose();
      _excerptController.dispose();
      _locationController.dispose();
      _addressController.dispose();
      _organizerController.dispose();
    }
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
    _titleController.dispose();
    _contentController.dispose();
    _excerptController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _organizerController.dispose();
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
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Select Categories"),
              content: SingleChildScrollView(
                child: ListBody(
                  children: allCategories.map<Widget>((category) {
                    return CheckboxListTile(
                      value: categoryMap[category['id'].toString()],
                      title: Text(category['name']),
                      onChanged: (bool? selected) {
                        setStateDialog(() {
                          categoryMap[category['id'].toString()] = selected!;
                        });
                        setState(() {
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

  Future<void> _selectDate(BuildContext context, {required bool isStartDate}) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now()),
      );
      if (pickedTime != null) {
        final DateTime finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          if (isStartDate) {
            _startDate = finalDateTime;
          } else {
            _endDate = finalDateTime;
          }
        });
      }
    }
  }

  void _initializeVideoController(String path) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate() || _image == null) return;

    final String contentPlainText = _contentController.document.toPlainText();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
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
        startDate: _startDate!,
        endDate: _endDate!,
        location: _locationController.text,
        address: _addressController.text,
        organizer: _organizerController.text,
        categoryIds: selectedCategoryIds,
      );

      if (success) {
        _titleController.clear();
        _excerptController.clear();
        _locationController.clear();
        _addressController.clear();
        _organizerController.clear();
        _contentController = ZefyrController(NotusDocument());
        setState(() {
          _image = null;
          _startDate = null;
          _endDate = null;

        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PostDetailsScreen(postId: mediaId)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao criar post')));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao fazer upload da mídia')));
    }
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
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: GestureDetector(
                  onTap: () => _showCategoryDialog(),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.blue),
                      SizedBox(width: 10),
                      Text("Categorias"),
                    ],
                  ),
                ),
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => value == null || value.isEmpty ? 'Por favor, insira um título' : null,
              ),
              ZefyrToolbar.basic(controller: _contentController),
              Container(
                height: 300,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: ZefyrEditor(controller: _contentController),
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Localização'),
                validator: (value) => value == null || value.isEmpty ? 'Por favor, insira uma localização' : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Endereço'),
                validator: (value) => value == null || value.isEmpty ? 'Por favor, insira um endereço' : null,
              ),
              TextFormField(
                controller: _organizerController,
                decoration: const InputDecoration(labelText: 'Organizador'),
                validator: (value) => value == null || value.isEmpty ? 'Por favor, insira um organizador' : null,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: () => _selectDate(context, isStartDate: true),
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(10),
                            backgroundColor: Colors.green,
                          ),
                          child: const Icon(Icons.calendar_today, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Início: ${_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Não selecionada'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: () => _selectDate(context, isStartDate: false),
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(10),
                            backgroundColor: Colors.red,
                          ),
                          child: const Icon(Icons.calendar_today_outlined, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Término: ${_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Não selecionada'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      height: 1,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),


              const SizedBox(height: 20),
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
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: isVideo
                      ? _videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                      : Container()
                      : Image.file(File(_image!.path), height: 200),
                ),
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  onPressed: _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  child: const Text('Enviar Post'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
