import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:maybe_async_annotations/maybe_async_annotations.dart';
import 'package:source_gen/source_gen.dart';

class MaybeAsyncGenerator extends GeneratorForAnnotation<MaybeAsync> {
  const MaybeAsyncGenerator();

  @override
  generateForAnnotatedElement(Element2 element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement2) {
      throw InvalidGenerationSourceError('@MaybeAsync can only be applied to classes.', element: element);
    }

    final classElement = element;

    return Future(() async {
      final source = await buildStep.readAsString(buildStep.inputId);
      final sb = StringBuffer();

      // Get source range of the class using the offset of the name
      sb.writeln(classElement.firstFragment.element.documentationComment);
      final nameStart = classElement.firstFragment.offset;
      final nameEnd = classElement.name3!.length + nameStart;
      final classEnd = classElement.fragments.last.nextFragment?.offset;

      final name = "Generated${classElement.name3}";

      sb.write(name);
      sb.write(source.substring(nameEnd, classEnd));

      // var pasteFrom = nameEnd;
      // for (final constructor in classElement.constructors2) {
      //   constructor.firstFragment.documentationComment        
      // }

      return sb.toString();
    });
  }
}
