import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/auth_notifier.dart';

class ApiSessionButton extends StatelessWidget {
  const ApiSessionButton({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    if (!auth.enabled || !auth.loggedIn) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Учётная запись: ${auth.fullName} · ${auth.user!.role.label}',
      onSelected: (_) async {
        await auth.logout();
        if (context.mounted) context.go('/login');
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text('${auth.fullName}\n${auth.user!.role.label}'),
        ),
        const PopupMenuItem(value: 'logout', child: Text('Выйти из системы')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined),
            if (MediaQuery.sizeOf(context).width >= 1000) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  auth.fullName ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
