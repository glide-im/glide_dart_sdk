class GlideException implements Exception {
  final String message;

  static const unauthorized = GlideException(message: "unauthorized");
  static const authorizeFailed = GlideException(message: "authorize failed");

  static const ackTimeout =
      GlideException(message: "await server ack message timeout");
  static const cacheUnavailable = GlideException(message: "cache unavailable");

  const GlideException({required this.message});
}
