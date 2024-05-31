import 'dart:io';

class Logger {
  static bool _isDebug = true;
  static IOSink? _sink;

  static void mark() {
    _log('MARK', '-', _getFileLineInfo(1));
  }

  static void setSink(IOSink? sink){
    _sink = sink;
  }

  static void setDebug() {
    _isDebug = true;
  }

  static void debug(String tag, dynamic message) {
    _log("DEBUG", tag, message);
  }

  static void warn(String tag, dynamic message) {
    _log("WARN", tag, message);
  }

  static void err(String tag, dynamic error) {
    _log("ERROR", tag, _getFileLineInfo(1));
    _log("ERROR", tag, error);
  }

  static void errTrace(String tag, dynamic error, StackTrace trace) {
    _log("ERROR", tag, '$error\n$trace');
  }

  static void info(String tag, dynamic message) {
    _log("INFO", tag, message);
  }

  static void _log(String level, String tag, dynamic message) {
    if (!_isDebug) {
      return;
    }
    final t = DateTime.now().toIso8601String();
    final l = '$level/$tag: $message';
    // stdout.writeln(l);
    _sink?.writeln(l);
  }

  static String _getFileLineInfo(int deep) {
    StackTrace trace = StackTrace.current;
    var traceString = trace.toString().split("\n")[deep + 1];
    var fileInfo = traceString.substring(traceString.indexOf('(') + 1, traceString.lastIndexOf(')'));
    // var listOfInfos = fileInfo.split(":");
    // final fileName = listOfInfos[0];
    // final lineNumber = int.parse(listOfInfos[1]);
    // var columnStr = listOfInfos[2];
    // columnStr = columnStr.replaceFirst(")", "");
    // return '.$fileName:$lineNumber:$columnStr';
    return fileInfo;
  }
}
