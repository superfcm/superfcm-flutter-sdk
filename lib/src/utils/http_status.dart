/// Represents standard HTTP status codes used in API responses.
///
/// Each enum value contains:
/// - a status code (e.g., 200, 404)
/// - a human-readable name (e.g., "OK", "Not Found")
enum HttpStatus {
  /// 200 OK: The request was successful.
  ok(200, "OK"),

  /// 201 Created: The request was successful and a new resource was created.
  created(201, "Created"),

  /// 204 No Content: The request was successful but returns no content.
  noContent(204, "No Content"),

  /// 400 Bad Request: The request was malformed or contains invalid parameters.
  badRequest(400, "Bad Request"),

  /// 401 Unauthorized: Authentication is required and has failed or not been provided.
  unauthorized(401, "Unauthorized"),

  /// 403 Forbidden: The server understood the request but refuses to authorize it.
  forbidden(403, "Forbidden"),

  /// 404 Not Found: The requested resource could not be found.
  notFound(404, "Not Found"),

  /// 409 Conflict: The request conflicts with the current state of the server.
  conflict(409, "Conflict"),

  /// 429 Too Many Attempts: Too many requests sent in a given amount of time.
  tooManyAttempts(429, "Too Many Attempts"),

  /// 500 Internal Server Error: The server encountered an unexpected error.
  internalServerError(500, "Internal Server Error"),

  /// 502 Bad Gateway: The server received an invalid response from an upstream server.
  badGateway(502, "Bad Gateway"),

  /// 503 Service Unavailable: The server is currently unavailable.
  serviceUnavailable(503, "Service Unavailable"),

  /// 999 Unknown: Represents an unrecognized or unhandled status code.
  unknown(999, "Unknown");

  /// The numeric HTTP status code.
  final int code;

  /// The human-readable name of the status.
  final String name;

  const HttpStatus(this.code, this.name);

  /// Creates an HttpStatus enum value from a numeric HTTP status code.
  ///
  /// Returns the corresponding HttpStatus enum value if found,
  /// or defaults to [HttpStatus.internalServerError] if the code is not recognized.
  ///
  /// [code] - The numeric HTTP status code to convert.
  static HttpStatus? fromCode(int code) {
    return HttpStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => HttpStatus.internalServerError,
    );
  }
}
