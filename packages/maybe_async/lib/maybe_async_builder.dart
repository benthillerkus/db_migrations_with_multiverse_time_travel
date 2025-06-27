import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'generator.dart';

/// Entry point for the maybe_async builder as defined in `build.yaml`.
Builder maybeAsyncBuilder(BuilderOptions options) {
  return SharedPartBuilder(const [MaybeAsyncGenerator()], 'maybe_async');
}
