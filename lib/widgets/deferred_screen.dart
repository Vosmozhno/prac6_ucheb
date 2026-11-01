import 'package:flutter/material.dart';
import 'feedback_panel.dart';

class DeferredScreen extends StatefulWidget {
  const DeferredScreen({super.key, required this.load, required this.builder});
  final Future<dynamic> Function() load;
  final WidgetBuilder builder;
  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<dynamic> _loading = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FeedbackPanel(
              icon: Icons.cloud_off_outlined,
              title: 'Раздел не загрузился',
              message: 'Проверьте соединение и повторите загрузку.',
              isError: true,
              action: OutlinedButton(
                onPressed: () => setState(() => _loading = widget.load()),
                child: const Text('Повторить'),
              ),
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Загрузка раздела'),
        );
      }
      return widget.builder(context);
    },
  );
}
