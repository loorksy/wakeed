class PlatformApiException implements Exception {
  PlatformApiException(
    this.message, {
    this.status,
    this.code,
    this.isAuth = false,
    this.isOffline = false,
  });

  final String message;
  final int? status;
  final String? code;
  final bool isAuth;
  final bool isOffline;

  @override
  String toString() => message;
}
