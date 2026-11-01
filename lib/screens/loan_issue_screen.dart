import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/loan_issue_notifier.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/library_scaffold.dart';

class LoanIssueScreen extends StatefulWidget {
  const LoanIssueScreen({super.key, required this.bookId});
  final int bookId;
  @override
  State<LoanIssueScreen> createState() => _LoanIssueScreenState();
}

class _LoanIssueScreenState extends State<LoanIssueScreen> {
  Timer? _debounce;
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LoanIssueNotifier>();
    return LibraryScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: state.saving
                      ? null
                      : () => context.go('/books/${widget.bookId}'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('К книге'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Выдача книги',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                if (state.loading)
                  const Center(child: CircularProgressIndicator())
                else if (state.book == null)
                  FeedbackPanel(
                    icon: Icons.cloud_off_outlined,
                    title: 'Не удалось открыть выдачу',
                    message: state.error ?? 'Повторите запрос.',
                    action: OutlinedButton(
                      onPressed: state.load,
                      child: const Text('Повторить'),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.book!.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Доступно экземпляров: ${state.book!.copiesAvailable}',
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            enabled: !state.saving,
                            decoration: const InputDecoration(
                              labelText: 'Найти читателя',
                              hintText: 'ФИО, почта или телефон',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (text) {
                              _debounce?.cancel();
                              state.cancelSearch();
                              _debounce = Timer(
                                const Duration(milliseconds: 400),
                                () => state.search(text),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          if (state.searching) const LinearProgressIndicator(),
                          DropdownButtonFormField<int>(
                            key: ValueKey(
                              'loan-reader-${state.readerId}-${state.readers.map((r) => r.id).join(',')}',
                            ),
                            initialValue: state.readerId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Читатель',
                              errorText: state.errors['readerId'],
                            ),
                            items: [
                              for (final reader in state.readers)
                                DropdownMenuItem(
                                  value: reader.id,
                                  child: Text(
                                    '${reader.fullName} · ${reader.card.number}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: state.saving || state.searching
                                ? null
                                : state.select,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            initialValue: '14',
                            enabled: !state.saving,
                            keyboardType: TextInputType.number,
                            onChanged: state.setDays,
                            decoration: InputDecoration(
                              labelText: 'Срок выдачи, дней',
                              helperText: 'От 1 до 90 дней',
                              errorText: state.errors['days'],
                            ),
                          ),
                          if (state.error != null) ...[
                            const SizedBox(height: 24),
                            FeedbackPanel(
                              icon: Icons.info_outline,
                              title: 'Выдача не оформлена',
                              message: state.error!,
                              isError: true,
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (state.saving) const LinearProgressIndicator(),
                          FilledButton.icon(
                            onPressed: state.saving || state.searching
                                ? null
                                : () async {
                                    final id = await state.save();
                                    if (id != null && context.mounted) {
                                      context.go('/books/${widget.bookId}');
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Выдача №$id оформлена.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.assignment_outlined),
                            label: Text(
                              state.saving ? 'Сохраняем…' : 'Оформить выдачу',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
