// lib/views/screens/edit_post_screen.dart

import 'package:flutter/material.dart';
import 'package:zefyrka/zefyrka.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import '../../models/post_model.dart';
import '../../models/weather_forecast.dart';
import '../../services/wordpress_service.dart';
import 'package:intl/intl.dart';


class EditPostScreen extends StatefulWidget {
  final Post post;
  final WeatherForecast? weatherForecast;
  final Evento? evento;
  final List<String> categoryIds;
  const EditPostScreen({super.key, required this.post, this.weatherForecast, this.evento,required this.categoryIds,});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _titleController;
  late TextEditingController _excerptController;
  late ZefyrController _contentController;
  late TextEditingController _eventLocationController;
  late TextEditingController _eventAddressController;
  late TextEditingController _eventOrganizerController;
  DateTime? _eventStartDate;
  DateTime? _eventEndDate;
  Map<String, String> videoPlaceholders = {};
  final _formKey = GlobalKey<FormState>();
  late WordPressService wordpressService;
  List<dynamic> _categories = [];
  List<String> _selectedCategoryIds = [];

  final Map<String, String> _postStatusOptions = {
    'publish': 'Publicada',
    'draft': 'Rascunho',
    'trash': 'Lixeira',
  };
  String _currentPostStatus = 'publish';

  @override
  void initState() {
    super.initState();
    wordpressService = WordPressService();

    _titleController = TextEditingController(text: widget.post.title);
    _excerptController = TextEditingController(text: widget.post.excerpt);

    _initializeContentController();
    _initializeEventControllers();
    _fetchCategories(); _selectedCategoryIds = List.from(widget.categoryIds);
    _currentPostStatus = widget.post.status ?? 'publish';
  }

  void _initializeContentController() {
    String processedContent = prepareContentForEditor(widget.post.content);
    final document = NotusDocument()..insert(0, processedContent);
    _contentController = ZefyrController(document);
  }

  void _initializeEventControllers() {
    _eventLocationController = TextEditingController();
    _eventAddressController = TextEditingController();
    _eventOrganizerController = TextEditingController();
    fetchEventDetails();
  }

  void _fetchCategories() async {
    _categories = await wordpressService.fetchCategories();
    setState(() {});
  }
  void _showCategoryDialog() async {
    final Map<String, bool> categoryMap = {for (var cat in _categories) cat['id'].toString(): _selectedCategoryIds.contains(cat['id'].toString())};
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Select Categories"),
              content: SingleChildScrollView(
                child: ListBody(
                  children: _categories.map<Widget>((category) {
                    return CheckboxListTile(
                      title: Text(category['name']),
                      value: categoryMap[category['id'].toString()],
                      onChanged: (bool? selected) {
                        setStateDialog(() => categoryMap[category['id'].toString()] = selected!);
                        if (selected == true) {
                          if (!_selectedCategoryIds.contains(category['id'].toString())) {
                            _selectedCategoryIds.add(category['id'].toString());
                          }
                        } else {
                          _selectedCategoryIds.remove(category['id'].toString());
                        }
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }
  String prepareContentForEditor(String htmlContent) {
    dom.Document document = parse(htmlContent);
    int videoCount = 0;

    document.querySelectorAll('video').forEach((videoElement) {
      String videoHtml = videoElement.outerHtml;
      String placeholder = "[video-${++videoCount}]";
      videoPlaceholders[placeholder] = videoHtml;
      videoElement.replaceWith(dom.Text(placeholder));
    });
    return document.body!.text;
  }

  String prepareEditedContentForSaving(String editedContent) {
    videoPlaceholders.forEach((placeholder, videoHtml) {
      editedContent = editedContent.replaceAll(placeholder, videoHtml);
    });

    return '<p>${editedContent.replaceAll('\n', '</p><p>')}</p>';
  }

  Future<void> fetchEventDetails() async {
    // Obtendo o token JWT
    final String? token = await wordpressService.getJwtToken();
    if (token == null) {
      print("JWT Token not found. Cannot fetch event details.");
      return;
    }

    // Agora passando o token JWT como argumento
    final eventoFetched = await wordpressService.fetchEventByPostId(widget.post.id, token);
    if (eventoFetched != null) {
      setState(() {
        _eventLocationController.text = eventoFetched.location;
        _eventAddressController.text = eventoFetched.address;
        _eventOrganizerController.text = eventoFetched.organizer;
        _eventStartDate = eventoFetched.startDate;
        _eventEndDate = eventoFetched.endDate;
      });
    } else {
      print("No event associated with this post.");
    }
  }


  Future<void> _selectDate(BuildContext context, {required bool isStartDate}) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _eventStartDate ?? DateTime.now() : _eventEndDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStartDate ? _eventStartDate ?? DateTime.now() : _eventEndDate ?? DateTime.now()),
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
            _eventStartDate = finalDateTime;
          } else {
            _eventEndDate = finalDateTime;
          }
        });
      }
    }
  }

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentPostStatus == 'trash') {
      // Chamar método para enviar o post para a lixeira
      bool trashSuccess = await wordpressService.trashPost(widget.post.id);
      if (trashSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post moved to trash successfully!')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to move the post to trash.')));
      }
      return;
    }

    // Se o status não for 'trash', continue com a atualização do post
    List<int> categoryIdsToInt = _selectedCategoryIds.map(int.parse).toList();
    String editedContent = prepareEditedContentForSaving(_contentController.document.toPlainText());
    bool postSuccess = await wordpressService.updatePost(
      postId: widget.post.id,
      title: _titleController.text,
      content: editedContent,
      categoryIds: categoryIdsToInt,
      status: _currentPostStatus,
    );

    if (postSuccess) {
      await _updateEvent();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post and event updated successfully!')));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update the post or event.')));
    }
  }



  Future<void> _updateEvent() async {
    if (_eventStartDate == null || _eventEndDate == null) {
      print("No event date provided. Skipping event update.");
      return;
    }

    bool eventSuccess = await wordpressService.updateEvent(
      postId: widget.post.id,
      startDate: _eventStartDate!,
      endDate: _eventEndDate!,
      location: _eventLocationController.text,
      address: _eventAddressController.text,
      organizer: _eventOrganizerController.text,
    );

    if (!eventSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update the event.')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8.0,
                children: _selectedCategoryIds.map((id) {
                  final category = _categories.firstWhere((cat) => cat['id'].toString() == id, orElse: () => null);
                  return Chip(
                    label: Text(category != null ? category['name'] : 'Unknown Category'),
                    onDeleted: () {
                      setState(() {
                        _selectedCategoryIds.remove(id);
                      });
                    },
                  );
                }).toList(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10), // Ajusta o espaçamento conforme necessário
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(width: 1.0, color: Colors.grey.shade300), // Cor e largura personalizáveis
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10), // Adiciona espaçamento após a borda
                    child: Wrap(
                      spacing: 8.0,
                      children: _postStatusOptions.entries.map((entry) {
                        return ChoiceChip(
                          label: Text(entry.value),
                          selected: _currentPostStatus == entry.key,
                          onSelected: (bool selected) {
                            setState(() {
                              _currentPostStatus = entry.key;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: GestureDetector(
                  onTap: () => _showCategoryDialog(),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.blue),
                      SizedBox(width: 10),
                      const Text("Categorias"),
                    ],
                  ),
                ),
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
              ),
              ZefyrToolbar.basic(controller: _contentController),
              Container(
                height: 400,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: ZefyrEditor(
                  controller: _contentController,
                  padding: const EdgeInsets.all(8),
                ),
              ),
              TextFormField(
                controller: _eventLocationController,
                decoration: const InputDecoration(
                    labelText: 'Event Location'),
                validator: (value) =>
                value!.isEmpty
                    ? 'Please enter the event location'
                    : null,
              ),
              TextFormField(
                controller: _eventAddressController,
                decoration: const InputDecoration(labelText: 'Event Address'),
                validator: (value) =>
                value!.isEmpty
                    ? 'Please enter the event address'
                    : null,
              ),
              TextFormField(
                controller: _eventOrganizerController,
                decoration: const InputDecoration(
                    labelText: 'Event Organizer'),
                validator: (value) =>
                value!.isEmpty
                    ? 'Please enter the event organizer'
                    : null,
              ),
              InkWell(
                onTap: () => _selectDate(context, isStartDate: true),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Start Date'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_eventStartDate == null
                          ? 'Select date'
                          : DateFormat('dd/MM/yyyy').format(
                          _eventStartDate!)),
                      Icon(Icons.arrow_drop_down, color: Theme
                          .of(context)
                          .brightness == Brightness.light ? Colors.grey
                          .shade700 : Colors.white70),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => _selectDate(context, isStartDate: false),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'End Date'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_eventEndDate == null ? 'Select date' : DateFormat(
                          'dd/MM/yyyy').format(_eventEndDate!)),
                      Icon(Icons.arrow_drop_down, color: Theme
                          .of(context)
                          .brightness == Brightness.light ? Colors.grey
                          .shade700 : Colors.white70),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: ElevatedButton(
                  onPressed: _updatePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme
                        .of(context)
                        .primaryColor,
                    // Cor de fundo do botão
                    foregroundColor: Colors.white,
                    // Cor do texto e ícones do botão
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
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

  @override
  void dispose() {
    _titleController.dispose();
    _excerptController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
