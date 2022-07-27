class Logger {
  static final Logger _logger = Logger(isDebug: true);

  bool _isDebug = false;

  Logger({bool isDebug = false}) {
    _isDebug = isDebug;
  }

  static void setDebug() {
    _logger._isDebug = true;
  }

  static void debug(String tag, dynamic message) {
    _log("DEBUG", tag, message);
  }

  static void warn(String tag, dynamic message) {
    _log("WARN", tag, message);
  }

  static void err(String tag, dynamic error) {
    _log("ERR", tag, error);
  }

  static void info(String tag, dynamic message) {
    _log("INFO", tag, message);
  }

  static void _log(String level, String tag, dynamic message) {
    if (!_logger._isDebug) {
      return;
    }

    final t = DateTime.now();
    final s = "${t.hour}:${t.minute}:${t.second}.${t.millisecond}";
    print('$s\t$level/$tag: $message');
  }
}
