import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:maybe_async_annotations/maybe_async_annotations.dart';
import 'package:source_gen/source_gen.dart';

class MaybeAsyncGenerator extends GeneratorForAnnotation<MaybeAsync> {
  const MaybeAsyncGenerator();

  @override
  dynamic generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    final sb = StringBuffer();
    sb.writeln('/// Generated code for ${element.name}');
    sb.writeln(element.source!.contents.data);
    return sb.toString();
  }
}
