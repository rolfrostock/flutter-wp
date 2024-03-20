// lib/screens/home_screen/widgets/edit_post_screen.dart

import 'package:flutter/material.dart';
import 'package:zefyrka/zefyrka.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import '../../models/post_model.dart';
import '../../models/weather_forecast.dart';
import '../../services/wordpress_service.dart';
import '../../views/screens/post_detail_screen.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;
  final WeatherForecast? weatherForecast;

  const EditPostScreen({super.key, required this.post, this.weatherForecast});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _titleController;
  late TextEditingController _excerptController;
  late ZefyrController _contentController;
  final _formKey = GlobalKey<FormState>();
  late WordPressService wordpressService;
  Map<String, String> videoPlaceholders = {};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _excerptController = TextEditingController(text: widget.post.excerpt);

    String processedContent = prepareContentForEditor(widget.post.content);
    final document = NotusDocument()..insert(0, processedContent);
    _contentController = ZefyrController(document);
    wordpressService = WordPressService();
  }

  String prepareContentForEditor(String htmlContent) {
    dom.Document document = parse(htmlContent);
    int videoCount = 0;

    // Identifica e substitui elementos de vídeo por placeholders
    document.querySelectorAll('video').forEach((videoElement) {
      String videoHtml = videoElement.outerHtml;
      String placeholder = "[video-${++videoCount}]";
      videoPlaceholders[placeholder] = videoHtml;
      videoElement.replaceWith(dom.Text(placeholder));
    });

    // Retorna o HTML como texto, mas com vídeos substituídos por placeholders
    return document.body!.text;
  }

  String prepareEditedContentForSaving(String editedContent) {
    // Substitui placeholders de volta pelo HTML original do vídeo
    videoPlaceholders.forEach((placeholder, videoHtml) {
      editedContent = editedContent.replaceAll(placeholder, videoHtml);
    });

    return '<p>${editedContent.replaceAll('\n', '</p><p>')}</p>';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => value == null || value.isEmpty ? 'Por favor, insira um título' : null,
              ),
              //TextFormField(
              //  controller: _excerptController,
              //  decoration: const InputDecoration(labelText: 'Excerto'),
              //  maxLines: 2,
              //  validator: (value) => value == null || value.isEmpty ? 'Por favor, insira um excerto' : null,
              //),
              ZefyrToolbar.basic(controller: _contentController),
              Container(
                height: 500,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(width: 1.0, color: Colors.grey)),
                ),
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ZefyrEditor(
                  controller: _contentController,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    String updatedContent = prepareEditedContentForSaving(_contentController.document.toPlainText());
                    bool success = await wordpressService.updatePost(
                      widget.post.id,
                      _titleController.text,
                      updatedContent,
                      _excerptController.text,
                    );

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post atualizado com sucesso!')),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailsScreen(
                            postId: widget.post.id,
                            weatherForecast: widget.weatherForecast,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Falha ao atualizar o post.')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Salvar Alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _excerptController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}