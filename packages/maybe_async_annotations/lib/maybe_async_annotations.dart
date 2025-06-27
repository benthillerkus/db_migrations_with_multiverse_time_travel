class MaybeAsync {
  const MaybeAsync._();
}

/// Annotation for the code generator to allow generating a sync and async version of a function.
const MaybeAsync maybeAsync = MaybeAsync._();

/// Wrapper for a value that will be a [Future] in the async version of a function
/// and the [value] itself in the sync version.
class MaybeFuture<T> {
  MaybeFuture(this.value) {
    throw UnimplementedError("This class should be replaced by the code generator.");
  }

  final T value;

  /// {@macro maybe_async.maybeAwait}
  T maybeAwait() {
    throw UnimplementedError("This function should be replaced by the code generator.");
  }
}

/// {@template maybe_async.maybeFuture}
/// Retrieves the [MaybeFuture.value] of a [MaybeFuture] so that it can be used synchronously.
///
/// This function will be replaced by the code generator, with either
/// nothing in the sync version of a function,
/// or a call to `await` in the async version of a function.
/// {@endtemplate}
T maybeAwait<T>(MaybeFuture<T> maybeFuture) {
  throw UnimplementedError("This function should be replaced by the code generator.");
}

/// Just exists to make sure that function composition works correctly
@pragma('vm:prefer-inline')
T maybeAwaitSyncImpl<T>(T value) => value;

/// Just exists to make sure that function composition works correctly
@pragma('vm:prefer-inline')
Future<T> maybeAwaitAsyncImpl<T>(Future<T> future) => future;