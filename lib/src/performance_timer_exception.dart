class PerformanceTimerException implements Exception {
  String? message;
  String? type;

  PerformanceTimerException({
    required this.message,
    required this.type,
  });

  PerformanceTimerException.message(this.message);

  PerformanceTimerException.type(this.type);
}
