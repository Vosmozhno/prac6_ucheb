import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/genre.dart';
import '../models/list_query.dart';
import '../models/publisher.dart';
import '../models/reader.dart';
import '../state/entity_detail_notifier.dart';
import '../state/reference_list_notifier.dart';
import '../validation/validators.dart';
import 'entity_detail_screen.dart';

class ReferenceDetailScreen extends StatelessWidget {
  const ReferenceDetailScreen({
    super.key,
    required this.section,
    required this.id,
    this.back,
  });
  final String section;
  final int id;
  final String? back;
  @override
  Widget build(BuildContext context) => switch (section) {
    'genres' => EntityDetailScreen<Genre, ListQuery>(
      id: id,
      back: back,
      section: section,
      controller: context.read<EntityDetailNotifier<Genre>>(),
      listController: context.read<GenreListNotifier>(),
      titleOf: (g) => g.name,
      fields: (g) => {
        'ID': g.id.toString(),
        'Описание': g.description.isEmpty ? 'Не указано' : g.description,
      },
    ),
    'publishers' => EntityDetailScreen<Publisher, ListQuery>(
      id: id,
      back: back,
      section: section,
      controller: context.read<EntityDetailNotifier<Publisher>>(),
      listController: context.read<PublisherListNotifier>(),
      titleOf: (p) => p.name,
      fields: (p) => {
        'ID': p.id.toString(),
        'Город': p.city,
        'Год основания': p.foundedYear.toString(),
      },
    ),
    _ => EntityDetailScreen<Reader, ListQuery>(
      id: id,
      back: back,
      section: section,
      controller: context.read<EntityDetailNotifier<Reader>>(),
      listController: context.read<ReaderListNotifier>(),
      titleOf: (r) => r.fullName,
      fields: (r) => {
        'ID': r.id.toString(),
        'Почта': r.email,
        'Телефон': r.phone,
        'Читательский билет': r.card.number,
        'Дата выдачи': Validators.dateText(r.card.issuedAt),
        'Действителен до': Validators.dateText(r.card.expiresAt),
      },
    ),
  };
}
