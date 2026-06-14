import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'models.dart';

typedef _ParseNative = Pointer<Utf8> Function(Pointer<Uint8>, IntPtr);
typedef _ParseDart = Pointer<Utf8> Function(Pointer<Uint8>, int);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

class XlsParser {
  XlsParser({DynamicLibrary? library})
      : _library = library ?? _openLibrary();

  final DynamicLibrary _library;

  Timetable parse(Uint8List bytes) {
    final parse = _library
        .lookupFunction<_ParseNative, _ParseDart>('parse_timetable_xls');
    final free = _library
        .lookupFunction<_FreeNative, _FreeDart>('free_parser_string');
    final input = calloc<Uint8>(bytes.length);
    input.asTypedList(bytes.length).setAll(0, bytes);
    final output = parse(input, bytes.length);
    calloc.free(input);
    try {
      final result = jsonDecode(output.toDartString()) as Map<String, dynamic>;
      if (result['ok'] != true) {
        throw FormatException(result['error'] as String? ?? '课表解析失败');
      }
      return Timetable.fromJson(result['timetable'] as Map<String, dynamic>);
    } finally {
      free(output);
    }
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return DynamicLibrary.open('course_table_parser.dll');
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.process();
    }
    return DynamicLibrary.open('libcourse_table_parser.so');
  }
}

