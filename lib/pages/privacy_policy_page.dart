import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

const String _policyMarkdownPath = 'legal/privacy-policy.md';

const String _fallbackPolicyMarkdown = '''
# Privacy Policy

Last updated: Add effective date

Cura's current privacy policy text has not been added to this repository yet. Replace this starter text with the finalized policy from your PDF.

## Contact

For privacy questions, contact info@cura.coffee.
''';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  late final Future<List<_PolicyBlock>> _policy = _loadPolicy();

  Future<List<_PolicyBlock>> _loadPolicy() async {
    final Uri markdownUri = Uri.base.resolve(_policyMarkdownPath);

    String markdown = _fallbackPolicyMarkdown;
    try {
      final http.Response response = await http.get(markdownUri);
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        markdown = utf8.decode(response.bodyBytes);
      }
    } catch (_) {
      markdown = _fallbackPolicyMarkdown;
    }

    return _parsePolicyMarkdown(markdown);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: <Widget>[
          const _PrivacyHeader(),
          Expanded(
            child: FutureBuilder<List<_PolicyBlock>>(
              future: _policy,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<_PolicyBlock>> snapshot,
                  ) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.espresso,
                          ),
                        ),
                      );
                    }

                    return _PolicyDocument(blocks: snapshot.data!);
                  },
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyHeader extends StatelessWidget {
  const _PrivacyHeader();

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width >= 760;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: AppColors.espresso.withValues(alpha: 0.10)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 74,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 18),
            child: Row(
              children: <Widget>[
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.go('/'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 8,
                    ),
                    child: Text(
                      'Cura',
                      style: GoogleFonts.fraunces(
                        fontSize: wide ? 28 : 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: AppColors.espresso,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.espresso,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    'Home',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

class _PolicyDocument extends StatelessWidget {
  const _PolicyDocument({required this.blocks});

  final List<_PolicyBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width >= 760;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 40 : 22, 58, wide ? 40 : 22, 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SelectionArea(child: _MarkdownPolicyBody(blocks: blocks)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkdownPolicyBody extends StatelessWidget {
  const _MarkdownPolicyBody({required this.blocks});

  final List<_PolicyBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < blocks.length; i += 1) {
      final _PolicyBlock block = blocks[i];
      if (children.isNotEmpty) {
        children.add(SizedBox(height: _gapBefore(block)));
      }
      children.add(_buildBlock(context, block));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  double _gapBefore(_PolicyBlock block) {
    if (block.kind == _PolicyBlockKind.heading && block.level == 1) return 48;
    if (block.kind == _PolicyBlockKind.heading) return 38;
    if (block.kind == _PolicyBlockKind.bullets) return 16;
    return 18;
  }

  Widget _buildBlock(BuildContext context, _PolicyBlock block) {
    return switch (block.kind) {
      _PolicyBlockKind.heading => _PolicyHeading(
        text: block.text,
        level: block.level,
      ),
      _PolicyBlockKind.paragraph => Text(
        block.text,
        style: GoogleFonts.inter(
          fontSize: 16,
          height: 1.68,
          letterSpacing: 0,
          color: AppColors.mocha,
        ),
      ),
      _PolicyBlockKind.bullets => _PolicyBulletList(items: block.items),
    };
  }
}

class _PolicyHeading extends StatelessWidget {
  const _PolicyHeading({required this.text, required this.level});

  final String text;
  final int level;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.of(context).size.width < 620;
    if (level == 1) {
      return Text(
        text,
        style: GoogleFonts.fraunces(
          fontSize: compact ? 42 : 58,
          height: 1.04,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: AppColors.warmBlack,
        ),
      );
    }
    return Text(
      text,
      style: GoogleFonts.fraunces(
        fontSize: level == 2 ? (compact ? 28 : 34) : 22,
        height: 1.16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.warmBlack,
      ),
    );
  }
}

class _PolicyBulletList extends StatelessWidget {
  const _PolicyBulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.forest,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        height: 1.62,
                        letterSpacing: 0,
                        color: AppColors.mocha,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

enum _PolicyBlockKind { heading, paragraph, bullets }

class _PolicyBlock {
  const _PolicyBlock.heading(this.text, this.level)
    : kind = _PolicyBlockKind.heading,
      items = const <String>[];

  const _PolicyBlock.paragraph(this.text)
    : kind = _PolicyBlockKind.paragraph,
      level = 0,
      items = const <String>[];

  const _PolicyBlock.bullets(this.items)
    : kind = _PolicyBlockKind.bullets,
      level = 0,
      text = '';

  final _PolicyBlockKind kind;
  final String text;
  final int level;
  final List<String> items;
}

List<_PolicyBlock> _parsePolicyMarkdown(String markdown) {
  final List<_PolicyBlock> blocks = <_PolicyBlock>[];
  final List<String> paragraph = <String>[];
  final List<String> bullets = <String>[];
  bool inComment = false;

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(_PolicyBlock.paragraph(paragraph.join(' ')));
    paragraph.clear();
  }

  void flushBullets() {
    if (bullets.isEmpty) return;
    blocks.add(_PolicyBlock.bullets(List<String>.unmodifiable(bullets)));
    bullets.clear();
  }

  for (final String rawLine in const LineSplitter().convert(markdown)) {
    final String line = rawLine.trim();
    if (inComment) {
      if (line.contains('-->')) inComment = false;
      continue;
    }
    if (line.startsWith('<!--')) {
      inComment = !line.contains('-->');
      continue;
    }
    if (line.isEmpty) {
      flushParagraph();
      flushBullets();
      continue;
    }

    final RegExpMatch? heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
    if (heading != null) {
      flushParagraph();
      flushBullets();
      blocks.add(
        _PolicyBlock.heading(
          heading.group(2)!.trim(),
          heading.group(1)!.length,
        ),
      );
      continue;
    }

    final RegExpMatch? bullet = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
    if (bullet != null) {
      flushParagraph();
      bullets.add(bullet.group(1)!.trim());
      continue;
    }

    flushBullets();
    paragraph.add(line);
  }

  flushParagraph();
  flushBullets();

  if (blocks.isEmpty) {
    return _parsePolicyMarkdown(_fallbackPolicyMarkdown);
  }
  return List<_PolicyBlock>.unmodifiable(blocks);
}
