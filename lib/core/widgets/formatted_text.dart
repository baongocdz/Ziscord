import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Renders message text with markdown + mention support.
///
/// Markdown supported:
///   **bold**, *italic*, `code`, ~~strikethrough~~, ```code block```
///
/// Mentions: anything matching `@\S+` is highlighted (clickable if [onMentionTap]).
class FormattedText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final ValueChanged<String>? onMentionTap;

  const FormattedText({
    super.key,
    required this.text,
    this.baseStyle,
    this.onMentionTap,
  });

  static final _pattern = RegExp(
    r'```([\s\S]+?)```'
    r'|`([^`\n]+)`'
    r'|\*\*([^*\n]+)\*\*'
    r'|\*([^*\n]+)\*'
    r'|~~([^~\n]+)~~'
    r"|(@[\wÀ-ɏḀ-ỿ][\wÀ-ɏḀ-ỿ\s]*)",
  );

  @override
  Widget build(BuildContext context) {
    final base = baseStyle ??
        const TextStyle(color: AppColors.textPrimary, fontSize: 15);
    return Text.rich(
      TextSpan(style: base, children: _parse(text, base)),
    );
  }

  List<InlineSpan> _parse(String input, TextStyle base) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _pattern.allMatches(input)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: input.substring(lastEnd, match.start)));
      }

      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: base.copyWith(
            fontFamily: 'monospace',
            fontSize: (base.fontSize ?? 15) - 1,
            backgroundColor: Colors.black26,
          ),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: base.copyWith(
            fontFamily: 'monospace',
            fontSize: (base.fontSize ?? 15) - 1,
            backgroundColor: Colors.black26,
          ),
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(3),
          style: base.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(4) != null) {
        spans.add(TextSpan(
          text: match.group(4),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(5) != null) {
        spans.add(TextSpan(
          text: match.group(5),
          style:
              base.copyWith(decoration: TextDecoration.lineThrough),
        ));
      } else if (match.group(6) != null) {
        final mention = match.group(6)!;
        spans.add(TextSpan(
          text: mention,
          style: base.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
            backgroundColor: AppColors.accent.withValues(alpha: 0.15),
          ),
          recognizer: onMentionTap == null
              ? null
              : (TapGestureRecognizer()..onTap = () => onMentionTap!(mention)),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      spans.add(TextSpan(text: input.substring(lastEnd)));
    }
    return spans;
  }
}

