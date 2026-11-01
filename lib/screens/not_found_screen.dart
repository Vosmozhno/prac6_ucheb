import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/library_scaffold.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.location});
  final String location;
  @override
  Widget build(BuildContext context) => LibraryScaffold(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: FeedbackPanel(
        icon: Icons.wrong_location_outlined,
        title: 'Страница не найдена · 404',
        message: 'Адрес: $location',
        action: FilledButton(
          onPressed: () => context.go('/books'),
          child: const Text('Открыть каталог'),
        ),
      ),
    ),
  );
}
