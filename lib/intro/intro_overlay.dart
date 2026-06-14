import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// EDIT THESE: the words revealed one-by-one on first load.
/// Keep it short (≈3–6 words) so it reads in a few seconds.
const List<String> kIntroWords = <String>[
  'Find',
  'your',
  'focus',
  'with',
  'Cura.',
];

/// A first-load intro: each word fades + rises in sequence ("Apple style"),
/// holds briefly, then the whole overlay fades out to reveal the site.
class IntroOverlay extends StatefulWidget {
  const IntroOverlay({super.key, required this.onComplete});

  /// Called once the intro has fully played and faded out.
  final VoidCallback onComplete;

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay>
    with SingleTickerProviderStateMixin {
  // Timing knobs (seconds).
  static const double _perWord = 0.34; // gap between each word starting
  static const double _wordIn = 0.82; // how long each word takes to arrive
  static const double _hold = 0.72; // pause after the last word
  static const double _outFade = 0.72; // overlay fade-out

  late final AnimationController _c;
  late final double _total;
  late final Animation<double> _overlayOpacity;
  late final Animation<double> _phraseScale;
  late final TextStyle _wordStyle;

  @override
  void initState() {
    super.initState();
    final int n = kIntroWords.isEmpty ? 1 : kIntroWords.length;
    _total = (n - 1) * _perWord + _wordIn + _hold + _outFade;
    _c =
        AnimationController(
          vsync: this,
          duration: Duration(milliseconds: (_total * 1000).round()),
        )..addStatusListener((AnimationStatus s) {
          if (s == AnimationStatus.completed) widget.onComplete();
        });
    _overlayOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _c,
        curve: Interval(_outStartNorm, 1, curve: Curves.easeInOutCubic),
      ),
    );
    _phraseScale = Tween<double>(begin: 0.985, end: 1).animate(
      CurvedAnimation(
        parent: _c,
        curve: Interval(0, _outStartNorm, curve: Curves.easeOutCubic),
      ),
    );
    _wordStyle = GoogleFonts.fraunces(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: AppColors.warmBlack,
    );
    _warmFontsAndStart();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _outStartNorm => (_total - _outFade) / _total;

  Future<void> _warmFontsAndStart() async {
    // Calling the style above queues the font load. Waiting briefly prevents
    // the first intro frames from being spent fetching/swapping the display
    // font, which is especially visible during hot restart on web.
    try {
      await GoogleFonts.pendingFonts().timeout(
        const Duration(milliseconds: 700),
      );
    } catch (_) {
      // Start anyway if the font is slow or unavailable; the app should not
      // block on a network font.
    }
    if (!mounted) return;
    _c.forward();
  }

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double fontSize = w < 600 ? 32 : 60;

    return FadeTransition(
      opacity: _overlayOpacity,
      child: RepaintBoundary(
        // Material (not ColoredBox) so the intro text has a DefaultTextStyle
        // ancestor; otherwise Flutter paints the debug yellow underline.
        child: Material(
          color: AppColors.border,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ScaleTransition(
                scale: _phraseScale,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: fontSize * 0.24,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int i = 0; i < kIntroWords.length; i++)
                      _IntroWord(
                        controller: _c,
                        total: _total,
                        start: i * _perWord,
                        duration: _wordIn,
                        word: kIntroWords[i],
                        style: _wordStyle.copyWith(fontSize: fontSize),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroWord extends StatelessWidget {
  const _IntroWord({
    required this.controller,
    required this.total,
    required this.start,
    required this.duration,
    required this.word,
    required this.style,
  });

  final AnimationController controller;
  final double total;
  final double start;
  final double duration;
  final String word;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final double begin = (start / total).clamp(0.0, 1.0);
    final double end = ((start + duration) / total).clamp(begin, 1.0);
    final Animation<double> arrival = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: arrival,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.34),
          end: Offset.zero,
        ).animate(arrival),
        child: Text(
          word,
          style: style,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      ),
    );
  }
}
