import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Scroll-driven video scrubber for Flutter Web.
///
/// Creates a real HTML `<video>` element and inserts it directly into the page
/// **behind** the transparent Flutter view (not via a fragile platform view).
/// It is centered and sized to the clip's true aspect ratio, with a 15%
/// top/bottom border (the page-body color) and a soft **feathered mask** so the
/// video's edges fade into the border instead of ending in a hard cut.
///
/// Loading: the clip is downloaded once with `http` and handed to the element
/// as an in-memory **blob URL** — this avoids dev servers without HTTP range
/// support and Chrome deferring media fetches, and makes every seek instant.
/// We then ease `currentTime` toward [progress] each frame so the scrub glides.
///
/// Requires the page background (web/index.html `body`) to be the desired
/// border color and the Flutter scaffold to be transparent.
class ScrollVideoScrubber extends StatefulWidget {
  const ScrollVideoScrubber({
    super.key,
    required this.src,
    required this.progress,
    this.smoothing = 0.14,
    this.topInsetVh = 0.15,
    this.bottomInsetVh = 0.15,
    this.onReady,
  });

  /// Video URL relative to the web root, e.g. `media/scene.mp4`.
  final String src;

  /// Scroll progress in [0, 1], mapped onto the video timeline.
  final ValueListenable<double> progress;

  /// Per-frame easing factor (0..1). Lower = softer, slower glide.
  final double smoothing;

  /// Top/bottom border as a fraction of viewport height (0.15 = 15%).
  final double topInsetVh;
  final double bottomInsetVh;

  /// Fired once the clip is buffered and primed for scrubbing.
  final VoidCallback? onReady;

  @override
  State<ScrollVideoScrubber> createState() => _ScrollVideoScrubberState();
}

class _ScrollVideoScrubberState extends State<ScrollVideoScrubber>
    with SingleTickerProviderStateMixin {
  static const String _domId = 'scroll-scrubber-video';

  // Soft fade on every edge so the video melts into the border instead of
  // ending in a hard cut. Tune the percentages for a wider/narrower fade.
  static const String _featherMask =
      'linear-gradient(to right, rgba(0,0,0,0), rgba(0,0,0,1) 6%, rgba(0,0,0,1) 94%, rgba(0,0,0,0)), '
      'linear-gradient(to bottom, rgba(0,0,0,0), rgba(0,0,0,1) 9%, rgba(0,0,0,1) 91%, rgba(0,0,0,0))';

  late final web.HTMLVideoElement _video;
  late final Ticker _ticker;
  late final JSFunction _canPlayCb;
  late final JSFunction _metaCb;
  late final JSFunction _errorCb;

  String? _objectUrl;
  bool _ready = false;
  double _shown = 0.0; // currently displayed time, in seconds

  double get _heightPct =>
      (1 - widget.topInsetVh - widget.bottomInsetVh) * 100;

  @override
  void initState() {
    super.initState();

    // Clear a stale element from a previous hot reload, if any.
    web.document.getElementById(_domId)?.remove();

    _video = web.HTMLVideoElement();
    _video
      ..id = _domId
      ..muted = true
      ..defaultMuted = true
      ..autoplay = false
      ..controls = false
      ..loop = false
      ..preload = 'auto';
    _video.setAttribute('playsinline', 'true');
    _video.setAttribute('disablepictureinpicture', 'true');

    final double topPct = widget.topInsetVh * 100;
    _video.style
      ..setProperty('position', 'fixed')
      ..setProperty('top', '${topPct}vh')
      ..setProperty('height', '${_heightPct}vh')
      ..setProperty('left', '50%')
      ..setProperty('transform', 'translateX(-50%)')
      // Width assumes 16:9 until the real dimensions load (see _applyAspect).
      ..setProperty('width', 'calc(${_heightPct}vh * 1.7778)')
      ..setProperty('max-width', '96vw')
      ..setProperty('object-fit', 'cover')
      ..setProperty('background', 'transparent')
      ..setProperty('pointer-events', 'none')
      ..setProperty('z-index', '0')
      ..setProperty('-webkit-mask-image', _featherMask)
      ..setProperty('mask-image', _featherMask)
      ..setProperty('-webkit-mask-repeat', 'no-repeat')
      ..setProperty('mask-repeat', 'no-repeat')
      ..setProperty('-webkit-mask-composite', 'source-in')
      ..setProperty('mask-composite', 'intersect');

    _canPlayCb = ((web.Event _) => _handleCanPlay()).toJS;
    _metaCb = ((web.Event _) => _applyAspect()).toJS;
    _errorCb = ((web.Event _) {}).toJS;
    _video.addEventListener('canplaythrough', _canPlayCb);
    _video.addEventListener('loadedmetadata', _metaCb);
    _video.addEventListener('error', _errorCb);

    // Insert as the first body child so it sits behind the Flutter view.
    final web.HTMLElement body = web.document.body!;
    body.insertBefore(_video, body.firstChild);

    _ticker = createTicker(_onTick)..start();
    _downloadAndAttach();
  }

  /// Size the element to the clip's true aspect ratio so there's no letterbox
  /// for the feather mask to fade (every visible edge is real video).
  void _applyAspect() {
    final int w = _video.videoWidth;
    final int h = _video.videoHeight;
    if (w > 0 && h > 0) {
      final double aspect = w / h;
      _video.style.setProperty('width', 'calc(${_heightPct}vh * $aspect)');
    }
  }

  Future<void> _downloadAndAttach() async {
    try {
      final http.Response resp = await http.get(Uri.base.resolve(widget.src));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final web.Blob blob = web.Blob(
          <JSAny>[resp.bodyBytes.toJS].toJS,
          web.BlobPropertyBag(type: 'video/mp4'),
        );
        _objectUrl = web.URL.createObjectURL(blob);
        _video.src = _objectUrl!;
        _video.load();
      } else {
        _markReady();
      }
    } catch (_) {
      _markReady();
    }
  }

  void _handleCanPlay() {
    if (_ready) return;
    // Prime the decode pipeline (notably Safari) with a muted play/pause.
    _video.play().toDart.then(
      (_) {
        _video.pause();
        _video.currentTime = 0;
        _markReady();
      },
      onError: (Object _) => _markReady(),
    );
  }

  void _markReady() {
    if (_ready || !mounted) return;
    setState(() => _ready = true);
    widget.onReady?.call();
  }

  void _onTick(Duration _) {
    if (!_ready) return;
    final double duration = _video.duration;
    if (duration.isNaN || duration <= 0) return;

    final double target = widget.progress.value.clamp(0.0, 1.0) * duration;
    _shown += (target - _shown) * widget.smoothing;
    if ((target - _shown).abs() < 0.004) _shown = target;

    final double t = _shown.clamp(0.0, duration - 0.001);
    if ((_video.currentTime - t).abs() > 0.003) {
      _video.currentTime = t;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _video.removeEventListener('canplaythrough', _canPlayCb);
    _video.removeEventListener('loadedmetadata', _metaCb);
    _video.removeEventListener('error', _errorCb);
    _video.removeAttribute('src');
    _video.load();
    _video.remove();
    if (_objectUrl != null) web.URL.revokeObjectURL(_objectUrl!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The <video> lives in the DOM behind Flutter; nothing to paint here.
    return const SizedBox.shrink();
  }
}
