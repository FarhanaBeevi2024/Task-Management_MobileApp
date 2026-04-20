import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../issues/providers/issues_providers.dart';
import '../models/project_model.dart';

/// Pastel fills for project avatars — index from [project.id] for stable “random” color.
const _avatarPastels = <Color>[
  Color(0xFFFFD6E8),
  Color(0xFFE8D6FF),
  Color(0xFFD6F5FF),
  Color(0xFFD6FFEA),
  Color(0xFFFFF3D6),
  Color(0xFFFFE0D6),
  Color(0xFFE0E8FF),
  Color(0xFFF0D6FF),
  Color(0xFFFFE8F0),
  Color(0xFFD8F0E8),
  Color(0xFFE8F0FF),
  Color(0xFFF5E6FF),
];

int _paletteIndex(String id) {
  final h = id.hashCode & 0x7fffffff;
  return h % _avatarPastels.length;
}

String _projectInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final s = parts.first;
    if (s.length >= 2) return s.substring(0, 2).toUpperCase();
    return s.substring(0, 1).toUpperCase();
  }
  String ch(String w) => w.isEmpty ? '' : w.substring(0, 1);
  return '${ch(parts[0])}${ch(parts[1])}'.toUpperCase();
}

Color _avatarBackground(Color pastel, Brightness brightness) {
  if (brightness == Brightness.dark) {
    return Color.lerp(pastel, const Color(0xFF1E1B2E), 0.58)!;
  }
  return pastel;
}

Color _initialsOnAvatar(Color background, ColorScheme scheme) {
  final luminance = background.computeLuminance();
  return luminance > 0.55 ? const Color(0xFF3D2B55) : scheme.onSurface.withValues(alpha: 0.92);
}

class ProjectTile extends ConsumerWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.onTap,
    this.onDelete,
  });

  final ProjectModel project;
  final VoidCallback onTap;

  /// When set, shows a delete control (caller should confirm + call API).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;
    final hasDesc = project.description != null && project.description!.trim().isNotEmpty;
    final borderLight = cs.outlineVariant.withValues(
      alpha: brightness == Brightness.dark ? 0.45 : 0.55,
    );
    final pastel = _avatarPastels[_paletteIndex(project.id)];
    final avatarBg = _avatarBackground(pastel, brightness);
    final initials = _projectInitials(project.name);
    final initialsStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: _initialsOnAvatar(avatarBg, cs),
    );

    final progressAsync = ref.watch(projectIssueProgressProvider(project.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surface,
        elevation: brightness == Brightness.dark ? 2 : 1.5,
        shadowColor: Colors.black.withValues(
          alpha: brightness == Brightness.dark ? 0.35 : 0.08,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderLight, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: avatarBg,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(initials, style: initialsStyle),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.15,
                                      color: cs.onSurface,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (hasDesc) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      project.description!.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        height: 1.35,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 4, top: 2),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: cs.onSurfaceVariant,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete project',
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: cs.error.withValues(alpha: 0.9),
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                ],
              ),
                const SizedBox(height: 12),
                progressAsync.when(
                  loading: () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                            color: cs.primary.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Loading progress…',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  error: (_, __) => _ProjectProgressRow(
                    fraction: 0,
                    percentLabel: '—',
                    caption: 'Could not load progress',
                    colorScheme: cs,
                    theme: theme,
                  ),
                  data: (p) => _ProjectProgressRow(
                    fraction: p.fraction,
                    percentLabel: p.total <= 0 ? '0%' : '${p.percent}%',
                    caption: p.total <= 0
                        ? 'No tasks yet'
                        : '${p.completed} of ${p.total} completed',
                    colorScheme: cs,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _ProjectProgressRow extends StatelessWidget {
  const _ProjectProgressRow({
    required this.fraction,
    required this.percentLabel,
    required this.caption,
    required this.colorScheme,
    required this.theme,
  });

  final double fraction;
  final String percentLabel;
  final String caption;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 40,
              child: Text(
                percentLabel,
                textAlign: TextAlign.end,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
