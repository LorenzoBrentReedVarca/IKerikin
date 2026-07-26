import 'package:flutter/material.dart';

/// Responsive centered content area with safe horizontal padding.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding,
  });
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
}

/// A responsive grid that keeps dashboard items readable without hardcoding
/// phone or tablet column counts.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 150,
    this.spacing = 10,
    this.childAspectRatio = 1.25,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
              .floor()
              .clamp(1, children.length);
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
        children: children,
      );
    },
  );
}

/// Child photo with a consistent fallback used throughout parent dashboards.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 28,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFE9E0FF),
    backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
    child: photoUrl == null
        ? Icon(
            Icons.child_care_rounded,
            size: radius,
            color: const Color(0xFF6738D1),
          )
        : null,
  );
}

/// Compact section heading with an optional trailing action.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      ?action,
    ],
  );
}

/// Friendly asynchronous state renderer.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.empty,
  });
  final AsyncSnapshot<T> value;
  final Widget Function(T data) data;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (value.hasError) return ErrorView(message: value.error.toString());
    if (!value.hasData) return const Center(child: CircularProgressIndicator());
    return data(value.data as T);
  }
}

/// Consistent empty state for first-use experiences.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    ),
  );
}

/// Friendly error state with an optional retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_rounded,
    title: 'Something went wrong',
    message: message.replaceFirst('Exception: ', ''),
    action: onRetry == null
        ? null
        : FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
  );
}

/// Labeled dashboard metric card.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: .13),
              foregroundColor: accent,
              child: Icon(icon),
            ),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Displays feedback after the current frame to avoid build-phase mutations.
void showMessage(BuildContext context, String message, {bool error = false}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  });
}
