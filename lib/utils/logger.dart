import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static const String _name = 'NFC_FIELD_LOGGER';
  static LogLevel _minLevel = LogLevel.debug;

  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  static void debug(String message, [Object? error]) {
    if (_minLevel.index <= LogLevel.debug.index) {
      developer.log(
        message,
        name: _name,
        level: 500, // Debug level
        error: error,
      );
    }
  }

  static void info(String message, [Object? error]) {
    if (_minLevel.index <= LogLevel.info.index) {
      developer.log(
        message,
        name: _name,
        level: 800, // Info level
        error: error,
      );
    }
  }

  static void warning(String message, [Object? error]) {
    if (_minLevel.index <= LogLevel.warning.index) {
      developer.log(
        message,
        name: _name,
        level: 900, // Warning level
        error: error,
      );
    }
  }

  static void error(String message, [Object? error]) {
    if (_minLevel.index <= LogLevel.error.index) {
      developer.log(
        message,
        name: _name,
        level: 1000, // Error level
        error: error,
      );
    }
  }
}