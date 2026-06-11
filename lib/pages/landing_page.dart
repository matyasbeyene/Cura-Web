import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../intro/intro_overlay.dart';
import '../scroll_video/scroll_video_scrubber.dart';
import '../theme/app_theme.dart';
import '../widgets/scroll_quotes.dart';
import '../widgets/top_nav.dart';

/// The landing page.
///
/// A first-load intro animation plays, then fades into the site. The hero is a
/// white field with the scroll-scrubbed video centered inside a 15% top/bottom
/// border; quote lines slide in from the sides as you scroll. Opaque content
/// sections then rise over the video. Video source + scroll length come from
/// `media/scene.json` at runtime (swap the clip with `tool/prep_video.ps1`).
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrubProgress = ValueNotifier<double>(0);
  final ValueNotifier<double> _navProgress = ValueNotifier<double>(0);

  // Config — overridable at runtime via media/scene.json.
  String _videoSrc = 'media/scene.mp4';
  double _scrollPages = 4.0; // hero scroll runway = pages x viewport height

  bool _configLoaded = false;
  bool _videoReady = false;
  bool _introDone = false;
  Timer? _loaderTimeout;

  @override
  void initState() {
    super.initState();
    // Dev helper: append ?nointro to the URL to skip the first-load animation.
    if (Uri.base.queryParameters.containsKey('nointro')) _introDone = true;
    _scroll.addListener(_onScroll);
    _loadConfig();
    _loaderTimeout = Timer(const Duration(seconds: 8), () {
      if (mounted && !_videoReady) setState(() => _videoReady = true);
    });
  }

  Future<void> _loadConfig() async {
    try {
      final http.Response resp =
          await http.get(Uri.base.resolve('media/scene.json'));
      if (resp.statusCode == 200) {
        final Map<String, dynamic> map =
            jsonDecode(resp.body) as Map<String, dynamic>;
        _videoSrc = (map['src'] as String?) ?? _videoSrc;
        final Object? pages = map['scrollPages'];
        if (pages is num) _scrollPages = pages.toDouble();
      }
    } catch (_) {
      // Keep defaults if the manifest is missing or malformed.
    } finally {
      if (mounted) setState(() => _configLoaded = true);
    }
  }

  void _onScroll() {
    if (!mounted) return;
    final double vh = MediaQuery.of(context).size.height;
    final double runway = vh * _scrollPages;
    final double off = _scroll.offset;
    _scrubProgress.value = runway <= 0 ? 0 : (off / runway).clamp(0.0, 1.0);
    _navProgress.value = (off / (vh * 0.55)).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _loaderTimeout?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrubProgress.dispose();
    _navProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced-motion visitors get a static poster page and no intro animation.
    if (MediaQuery.of(context).disableAnimations) {
      return _ReducedMotionPage(navProgress: _navProgress, scroll: _scroll);
    }
    // A single root Scaffold (so it reliably fills the screen) with the page
    // content and the first-load intro layered inside its body.
    return Scaffold(
      // Transparent so the page body (white, set in web/index.html) and the
      // DOM <video> behind Flutter show through as the video's white border.
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildContent(context),
          if (!_introDone)
            IntroOverlay(
              onComplete: () {
                if (mounted) setState(() => _introDone = true);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!_configLoaded) {
      return const _Loader();
    }

    final double vh = MediaQuery.of(context).size.height;
    final double runway = vh * _scrollPages;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 1. The scroll-scrubbed video. It manages a real <video> element in
        //    the page behind the transparent Flutter view, positioned with a
        //    15% top/bottom white border via CSS.
        Positioned.fill(
          child: ScrollVideoScrubber(
            src: _videoSrc,
            progress: _scrubProgress,
            onReady: () {
              if (mounted) setState(() => _videoReady = true);
            },
          ),
        ),

        // 2. Scrollable content over the video.
        Positioned.fill(
          child: SingleChildScrollView(
            controller: _scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: runway),
                const _ContentSections(),
              ],
            ),
          ),
        ),

        // 3. Foreground: scroll-driven quotes + scroll cue.
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: _scrubProgress,
              builder: (_, double p, _) => _HeroForeground(progress: p),
            ),
          ),
        ),

        // 4. Top navigation.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _navProgress,
            builder: (BuildContext context, double s, _) =>
                TopNav(scrolled: s, onSignIn: () => context.push('/sign-in')),
          ),
        ),

        // 5. Loading veil until the clip is primed.
        if (!_videoReady) const Positioned.fill(child: _Loader()),
      ],
    );
  }
}

/// Opaque white loader that hides the cold video while it buffers.
class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.border,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.espresso),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'brewing',
              style: GoogleFonts.inter(
                fontSize: 13,
                letterSpacing: 3,
                color: AppColors.mocha,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero foreground over the white field: the scroll quotes plus a scroll cue
/// that fades as soon as you begin scrolling.
class _HeroForeground extends StatelessWidget {
  const _HeroForeground({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final double cueOpacity = (1.0 - progress / 0.10).clamp(0.0, 1.0);
    return Stack(
      children: <Widget>[
        ScrollQuotes(progress: progress),
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: cueOpacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'SCROLL',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    letterSpacing: 3,
                    color: AppColors.mocha,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.mocha,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The opaque content that scrolls up over the video. Placeholder copy for now.
class _ContentSections extends StatelessWidget {
  const _ContentSections();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _IntroSection(),
        _FeaturesSection(),
        _CtaSection(),
      ],
    );
  }
}

class _IntroSection extends StatelessWidget {
  const _IntroSection();

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double size = w < 600 ? 32 : 46;
    return ColoredBox(
      color: AppColors.cream,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 150, horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: <Widget>[
                Text(
                  'From the first scroll to the last drop.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fraunces(
                    fontSize: size,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warmBlack,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Placeholder copy — this is where the story of the app lives. '
                  'The hero above plays frame-by-frame as you scroll; everything '
                  'down here follows the same warm, editorial system and is easy '
                  'to swap out later.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    height: 1.7,
                    color: AppColors.mocha,
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

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.latte,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 130, horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              children: <Widget>[
                Text(
                  'Crafted for the ritual',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fraunces(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warmBlack,
                  ),
                ),
                const SizedBox(height: 56),
                const Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    _FeatureCard(
                      icon: Icons.coffee_rounded,
                      title: 'Dialed in',
                      body: 'Placeholder feature copy describing the first '
                          'pillar of the product.',
                    ),
                    _FeatureCard(
                      icon: Icons.bolt_rounded,
                      title: 'Fast & fluid',
                      body: 'Placeholder feature copy describing the second '
                          'pillar of the product.',
                    ),
                    _FeatureCard(
                      icon: Icons.favorite_rounded,
                      title: 'Made to love',
                      body: 'Placeholder feature copy describing the third '
                          'pillar of the product.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.forestDark),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.warmBlack,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.55,
              color: AppColors.mocha,
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaSection extends StatelessWidget {
  const _CtaSection();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.espresso,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 130, horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: <Widget>[
                Text(
                  'Bring the ritual home.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fraunces(
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: AppColors.cream,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 34,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                  child: Text(
                    'Get the app',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                Text(
                  '© 2026 BREW · placeholder footer',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.cream.withValues(alpha: 0.6),
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

/// Accessibility fallback: when the OS requests reduced motion, show a still
/// poster hero instead of the scroll-scrubbed video (and no intro animation).
class _ReducedMotionPage extends StatelessWidget {
  const _ReducedMotionPage({required this.navProgress, required this.scroll});

  final ValueListenable<double> navProgress;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final double vh = MediaQuery.of(context).size.height;
    final double w = MediaQuery.of(context).size.width;
    final double titleSize = w < 600 ? 34 : 50;
    final String poster = Uri.base.resolve('media/poster.jpg').toString();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SingleChildScrollView(
              controller: scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: vh,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: vh * 0.15),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Flexible(
                              child: Image.network(poster, fit: BoxFit.contain),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'A daily ritual, in motion.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fraunces(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warmBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const _ContentSections(),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: navProgress,
              builder: (BuildContext context, double s, _) => TopNav(
                scrolled: s,
                onSignIn: () => context.push('/sign-in'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
