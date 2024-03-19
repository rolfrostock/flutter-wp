// lib/database/database.dart:

import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/post_model.dart';

Map<String, Post> generateRandomDatabase({
  required int maxGap,
  required int amount,
}) {
  Random rng = Random();
  var uuid = Uuid();

  Map<String, Post> map = {};

  for (int i = 0; i < amount; i++) {
    int timeGap = rng.nextInt(maxGap); // Define uma distância do hoje
    DateTime date = DateTime.now().subtract(Duration(days: timeGap)); // Gera um dia

    map[uuid.v1()] = Post(
      id: rng.nextInt(10000), // Gera um ID aleatório
      title: "Título ${uuid.v1()}", // Gera um título fictício
      content: "Conteúdo do post ${uuid.v1()}", // Gera um conteúdo fictício
      excerpt: "Resumo do post ${uuid.v1()}", // Gera um resumo fictício
      createdAt: date, // Usa a data gerada
    );
  }
  return map;
}