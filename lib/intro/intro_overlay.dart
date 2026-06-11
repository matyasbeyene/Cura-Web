import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// EDIT THESE: the words revealed one-by-one on first load.
/// Keep it short (≈3–6 words) so it reads in a few seconds.
const List<String> kIntroWords = <String>[
  'Every',
  'morning',
  'deserves',
  'a',
  'ritual.',
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
  static const double _perWord = 0.42; // gap between each word starting
  static const double _wordFade = 0.6; // how long each word takes to arrive
  static const double _hold = 0.9; // pause after the last word
  static const double _outFade = 0.6; // overlay fade-out

  late final AnimationController _c;
  late final double _total;

  @override
  void initState() {
    super.initState();
    final int n = kIntroWords.isEmpty ? 1 : kIntroWords.length;
    _total = (n - 1) * _perWord + _wordFade + _hold + _outFade;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_total * 1000).round()),
    )..addStatusListener((AnimationStatus s) {
        if (s == AnimationStatus.completed) widget.onComplete();
      });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _outStartNorm => (_total - _outFade) / _total;

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double fontSize = w < 600 ? 32 : 60;

    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        final double tNorm = _c.value;
        double overlayOpacity = 1.0;
        if (tNorm > _outStartNorm) {
          overlayOpacity =
              (1.0 - (tNorm - _outStartNorm) / (1.0 - _outStartNorm))
                  .clamp(0.0, 1.0);
        }
        final double elapsed = tNorm * _total;
        return Opacity(
          opacity: overlayOpacity,
          // Material (not ColoredBox) so the intro text has a DefaultTextStyle
          // ancestor — otherwise Flutter paints the debug yellow underline.
          child: Material(
            color: AppColors.border,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: fontSize * 0.28,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int i = 0; i < kIntroWords.length; i++)
                      _word(kIntroWords[i], i, fontSize, elapsed),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _word(String word, int i, double fontSize, double elapsed) {
    final double start = i * _perWord;
    final double raw = ((elapsed - start) / _wordFade).clamp(0.0, 1.0);
    final double eased = Curves.easeOut.transform(raw);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 18),
        child: Text(
          word,
          style: GoogleFonts.fraunces(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: AppColors.warmBlack,
          ),
        ),
      ),
    );
  }
}
