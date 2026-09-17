import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'config.dart';

Dio buildDio({
  String? Function()? tokenProvider,
  Future<void> Function()? refreshAccessToken,
  Future<void> Function()? onRefreshFailed,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (kDebugMode) {
          debugPrint(
            '[API] ${response.requestOptions.method} '
            '${response.requestOptions.uri} -> $status',
          );
        }
        if (status >= 400) {
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
          return;
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          debugPrint(
            '[API] ${error.requestOptions.method} '
            '${error.requestOptions.uri} -> ${error.response?.statusCode ?? error.type.name}',
          );
        }
        final status = error.response?.statusCode;
        final path = error.requestOptions.path;
        final alreadyRetried =
            error.requestOptions.extra['authRetried'] == true;
        if (status == 401 &&
            !path.contains('/auth/') &&
            !alreadyRetried &&
            refreshAccessToken != null) {
          try {
            await refreshAccessToken();
            final options = error.requestOptions;
            options.extra['authRetried'] = true;
            options.headers['Authorization'] =
                'Bearer ${tokenProvider?.call()}';
            return handler.resolve(await dio.fetch(options));
          } catch (_) {
            await onRefreshFailed?.call();
          }
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}
