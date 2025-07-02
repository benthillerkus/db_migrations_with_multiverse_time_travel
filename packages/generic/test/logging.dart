import 'dart:developer' as developer;

import 'package:ansicolor/ansicolor.dart';
import 'package:logging/logging.dart';

late Logger log;

void setUpLogging() {
  Logger.root.level = Level.ALL;
  log = Logger('test');
  final pen = AnsiPen();
  Logger.root.onRecord.listen((record) {
    switch (record.level) {
      case Level.WARNING:
        pen.yellow();
      case Level.SEVERE:
        pen.red();
      case Level.INFO:
        pen.blue();
      default:
        pen.white();
    }
    print(pen('[${record.loggerName}]\t${record.message}'));
    developer.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}
