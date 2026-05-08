class RenderTrace {
  static const bool enabled = false;

  static int _frameId = 0;
  static int _sequence = 0;

  static int get frameId => _frameId;

  static void beginFrame({String source = 'update'}) {
    if (!enabled) return;
    _frameId++;
    _sequence = 0;
    if (false) print('[RenderSequence] --- frame=$_frameId source=$source ---');
  }

  static void log(String label) {
    if (!enabled) return;
    _sequence++;
    final seq = _sequence.toString().padLeft(3, '0');
    if (false) print('[RenderSequence] $seq $label');
  }

  static void logCanvas({
    required String file,
    required String method,
    required String operation,
  }) {
    if (!enabled) return;
    if (false)
      print(
        '[CanvasTrace] file=$file method=$method operation=$operation '
        'frame=$_frameId seq=$_sequence',
      );
  }
}
