import 'package:flutter/material.dart';

import '../core/app_strings.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({required this.child, super.key, this.maxWidth = 1200});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 600 ? 24.0 : (width >= 390 ? 20.0 : 16.0);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
          child: child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (action != null) action!,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    super.key,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, required this.strings, super.key});

  final String status;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = <String, (Color, Color)>{
      'received': dark ? (const Color(0xFFBFDBFE), const Color(0xFF1E3A5F)) : (const Color(0xFF1D4ED8), const Color(0xFFE8EFFF)),
      'diagnosing': dark ? (const Color(0xFFDDD6FE), const Color(0xFF3A2858)) : (const Color(0xFF6D28D9), const Color(0xFFF0E9FF)),
      'awaiting_approval': dark ? (const Color(0xFFFDE68A), const Color(0xFF453415)) : (const Color(0xFF92400E), const Color(0xFFFFF3D6)),
      'awaiting_parts': dark ? (const Color(0xFFFED7AA), const Color(0xFF4B2B18)) : (const Color(0xFF9A3412), const Color(0xFFFFEDD5)),
      'in_progress': dark ? (const Color(0xFFBAE6FD), const Color(0xFF163B50)) : (const Color(0xFF155E75), const Color(0xFFE0F2FE)),
      'ready': dark ? (const Color(0xFFBBF7D0), const Color(0xFF183D2C)) : (const Color(0xFF166534), const Color(0xFFDCFCE7)),
      'delivered': dark ? (const Color(0xFFCBD5E1), const Color(0xFF334155)) : (const Color(0xFF475569), const Color(0xFFE2E8F0)),
      'cancelled': dark ? (const Color(0xFFFECACA), const Color(0xFF4A232B)) : (const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
    };
    final pair = colors[status] ?? (Theme.of(context).colorScheme.onSurface, Theme.of(context).colorScheme.surfaceContainerHighest);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: pair.$2, borderRadius: BorderRadius.circular(8)),
      child: Text(strings.status(status), style: TextStyle(color: pair.$1, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

String shortDate(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
}
