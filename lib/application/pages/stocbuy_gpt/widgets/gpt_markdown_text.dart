import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// Lightweight markdown for AI responses (`#` headings, bullets, `**bold**`).
class GptMarkdownText extends StatelessWidget {
  const GptMarkdownText({
    super.key,
    required this.data,
    this.baseStyle,
  });

  final String data;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final body = baseStyle ??
        const TextStyle(
          fontSize: 14,
          height: 1.55,
          fontWeight: FontWeight.w500,
          color: AppColors.darkblue,
        );

    final blocks = _parseBlocks(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          blocks[i].build(body),
        ],
      ],
    );
  }

  List<_MdBlock> _parseBlocks(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_MdBlock>[];
    final buf = <String>[];

    void flushParagraph() {
      if (buf.isEmpty) return;
      blocks.add(_MdParagraph(buf.join('\n')));
      buf.clear();
    }

    for (final line in lines) {
      final t = line.trimRight();
      if (t.isEmpty) {
        flushParagraph();
        continue;
      }
      if (t.startsWith('### ')) {
        flushParagraph();
        blocks.add(_MdHeading(t.substring(4), level: 3));
        continue;
      }
      if (t.startsWith('## ')) {
        flushParagraph();
        blocks.add(_MdHeading(t.substring(3), level: 2));
        continue;
      }
      if (t.startsWith('# ')) {
        flushParagraph();
        blocks.add(_MdHeading(t.substring(2), level: 1));
        continue;
      }
      if (t.startsWith('- ') || t.startsWith('* ')) {
        flushParagraph();
        blocks.add(_MdBullet(t.substring(2)));
        continue;
      }
      buf.add(t);
    }
    flushParagraph();
    return blocks;
  }
}

sealed class _MdBlock {
  Widget build(TextStyle base);
}

class _MdHeading extends _MdBlock {
  _MdHeading(this.text, {required this.level});
  final String text;
  final int level;

  @override
  Widget build(TextStyle base) {
    final size = switch (level) {
      1 => 18.0,
      2 => 16.0,
      _ => 14.5,
    };
    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 4 : 2, bottom: 4),
      child: _richText(
        text,
        base.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _MdParagraph extends _MdBlock {
  _MdParagraph(this.text);
  final String text;

  @override
  Widget build(TextStyle base) => _richText(text, base);
}

class _MdBullet extends _MdBlock {
  _MdBullet(this.text);
  final String text;

  @override
  Widget build(TextStyle base) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: base.copyWith(fontWeight: FontWeight.w700)),
          Expanded(child: _richText(text, base)),
        ],
      ),
    );
  }
}

Widget _richText(String input, TextStyle style) {
  final spans = <TextSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*');
  var start = 0;
  for (final m in re.allMatches(input)) {
    if (m.start > start) {
      spans.add(TextSpan(text: input.substring(start, m.start)));
    }
    spans.add(
      TextSpan(
        text: m.group(1),
        style: style.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    start = m.end;
  }
  if (start < input.length) {
    spans.add(TextSpan(text: input.substring(start)));
  }
  if (spans.isEmpty) {
    return Text(input, style: style);
  }
  return Text.rich(TextSpan(style: style, children: spans));
}
