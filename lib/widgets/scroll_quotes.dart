import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

enum QuoteSide { left, right }

/// A quote tied to a scroll-progress window. It slides in from its side and
/// fades in over the first part of the window, holds, then fades out.
class ScrollQuote {
  const ScrollQuote(this.text, this.side, this.start, this.end);

  final String text;
  final QuoteSide side;
  final double start; // scroll progress (0..1) where it begins appearing
  final double end; // scroll progress where it has fully gone
}

/// EDIT THESE: placeholder quotes. Per request the order is left → right → left.
/// Replace the text (and tweak the start/end windows to retime them).
const List<ScrollQuote> kScrollQuotes = <ScrollQuote>[
  ScrollQuote(
    '“Placeholder quote one — your first line goes here.”',
    QuoteSide.left,
    0.12,
    0.37,
  ),
  ScrollQuote(
    '“Placeholder quote two — your second line goes here.”',
    QuoteSide.right,
    0.41,
    0.66,
  ),
  ScrollQuote(
    '“Placeholder quote three — your third line goes here.”',
    QuoteSide.left,
    0.70,
    0.825,
  ),
];

/// Renders the scroll quotes for the current [progress] (0..1).
class ScrollQuotes extends StatelessWidget {
  const ScrollQuotes({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final bool narrow = w < 720;
    return Stack(
      children: <Widget>[
        for (final ScrollQuote q in kScrollQuotes)
          _buildQuote(q, narrow, w),
      ],
    );
  }

  Widget _buildQuote(ScrollQuote q, bool narrow, double w) {
    final double span = (q.end - q.start);
    if (span <= 0) return const SizedBox.shrink();
    final double local = ((progress - q.start) / span).clamp(0.0, 1.0);

    // Fade in over the first 30%, hold, fade out over the last 30%.
    double opacity;
    if (local <= 0.0 || local >= 1.0) {
      opacity = 0.0;
    } else if (local < 0.3) {
      opacity = local / 0.3;
    } else if (local > 0.7) {
      opacity = (1.0 - local) / 0.3;
    } else {
      opacity = 1.0;
    }
    if (opacity <= 0.0) return const SizedBox.shrink();

    // Slide in from the side while fading in; drift out gently while leaving.
    final double dir = q.side == QuoteSide.left ? -1.0 : 1.0;
    double dx;
    if (local < 0.3) {
      dx = dir * 80.0 * (1.0 - local / 0.3);
    } else if (local > 0.7) {
      dx = dir * 36.0 * ((local - 0.7) / 0.3);
    } else {
      dx = 0.0;
    }

    final double maxW = narrow ? w * 0.84 : w * 0.34;
    final Widget block = Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Text(
            q.text,
            textAlign:
                q.side == QuoteSide.left ? TextAlign.left : TextAlign.right,
            style: GoogleFonts.fraunces(
              fontSize: narrow ? 24 : 38,
              height: 1.25,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: AppColors.warmBlack,
            ),
          ),
        ),
      ),
    );

    if (narrow) {
      return Align(
        alignment: const Alignment(0, 0.45),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: block,
        ),
      );
    }
    return Align(
      alignment:
          q.side == QuoteSide.left ? const Alignment(-0.9, 0) : const Alignment(0.9, 0),
      child: block,
    );
  }
}
