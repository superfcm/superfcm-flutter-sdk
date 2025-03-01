import 'package:superfcm_flutter/src/utils/http_status.dart';

/// Represents the status of an API request.
enum RequestStatus {
  /// Request was successful (status code 2xx)
  success,

  /// Request was cached due to device being offline
  cached,

  /// Request failed due to client error (status code 4xx)
  clientError,

  /// Request failed due to server error (status code 5xx)
  serverError,

  /// Request failed due to network error
  networkError,

  /// Request failed due to unknown error
  unknownError,
}

/// Represents a response from the SuperFCM API.
///
/// Encapsulates the HTTP status and response data returned from API calls.
class ApiResponse {
  /// The HTTP status of the response.
  ///
  /// Contains both the status code and a human-readable status name.
  final HttpStatus httpStatus;

  /// The data payload of the response.
  ///
  /// Contains the parsed JSON response body as a map.
  final Map<String, dynamic> data;

  /// Indicates if the request was cached for later processing due to being offline.
  final bool isCached;

  /// The specific status of the request.
  final RequestStatus requestStatus;

  /// Creates a new ApiResponse instance.
  ///
  /// [httpStatus] - The HTTP status of the response
  /// [data] - The response data payload
  /// [isCached] - Whether this request was cached for later execution
  /// [requestStatus] - The specific status of the request
  ApiResponse({
    this.httpStatus = HttpStatus.unknown,
    this.data = const {},
    this.isCached = false,
    RequestStatus? requestStatus,
  }) : requestStatus = requestStatus ??
            ((httpStatus.code >= 200 && httpStatus.code < 300)
                ? RequestStatus.success
                : (httpStatus.code >= 400 && httpStatus.code < 500)
                    ? RequestStatus.clientError
                    : RequestStatus.serverError);

  /// Factory constructor for creating a cached response.
  factory ApiResponse.cached(Map<String, dynamic> data) {
    return ApiResponse(
      data: data,
      isCached: true,
      requestStatus: RequestStatus.cached,
    );
  }

  /// Factory constructor for creating a network error response.
  factory ApiResponse.networkError({String? message}) {
    return ApiResponse(
      data: {'error': message ?? 'Network error'},
      requestStatus: RequestStatus.networkError,
    );
  }

  /// Factory constructor for creating an unknown error response.
  factory ApiResponse.unknownError({String? message}) {
    return ApiResponse(
      data: {'error': message ?? 'Unknown error'},
      requestStatus: RequestStatus.unknownError,
    );
  }

  /// Indicates whether the request was successful.
  ///
  /// Returns true if the status code is in the 200-299 range,
  /// which represents successful HTTP responses.
  bool get success => httpStatus.code >= 200 && httpStatus.code < 300;
}
