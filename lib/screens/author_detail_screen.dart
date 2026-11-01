import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/author.dart';
import '../models/list_query.dart';
import '../state/author_list_notifier.dart';
import '../state/entity_detail_notifier.dart';
import 'entity_detail_screen.dart';

class AuthorDetailScreen extends StatelessWidget {
  const AuthorDetailScreen({super.key, required this.id, this.back});
  final int id;
  final String? back;
  @override
  Widget build(BuildContext context) => EntityDetailScreen<Author, ListQuery>(
    id: id,
    back: back,
    section: 'authors',
    controller: context.read<AuthorDetailNotifier>(),
    listController: context.read<AuthorListNotifier>(),
    titleOf: (author) => author.fullName,
    fields: (author) => {
      'ID': author.id.toString(),
      'Год рождения': author.birthYear.toString(),
      'Страна': author.country,
    },
  );
}
