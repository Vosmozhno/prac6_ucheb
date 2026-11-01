import 'package:flutter/material.dart';

class DetailSheet extends StatelessWidget {
  const DetailSheet({super.key, required this.title, required this.fields});
  final String title;
  final Map<String, String> fields;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            for (final entry in fields.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: constraints.maxWidth >= 500
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 180,
                            child: Text(
                              entry.key,
                              style: const TextStyle(color: Color(0xff64748b)),
                            ),
                          ),
                          Expanded(child: SelectableText(entry.value)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(color: Color(0xff64748b)),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(entry.value),
                        ],
                      ),
              ),
          ],
        ),
      ),
    ),
  );
}
