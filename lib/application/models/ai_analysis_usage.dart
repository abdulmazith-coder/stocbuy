import 'package:flutter/foundation.dart';

@immutable
class AiAnalysisUsage {
  const AiAnalysisUsage({
    required this.plan,
    required this.isUnlimited,
    required this.used,
    required this.limit,
    required this.remaining,
    required this.message,
  });

  final String plan;
  final bool isUnlimited;
  final int used;
  final int limit;
  final int remaining;
  final String message;

  bool get isExhausted => remaining <= 0;

  factory AiAnalysisUsage.fromJson(Map<String, dynamic> json) {
    return AiAnalysisUsage(
      plan: (json['plan'] ?? '').toString(),
      isUnlimited: json['is_unlimited'] == true,
      used: (json['used'] is num
          ? (json['used'] as num).toInt()
          : int.tryParse('${json['used']}') ?? 0),
      limit: (json['limit'] is num
          ? (json['limit'] as num).toInt()
          : int.tryParse('${json['limit']}') ?? 0),
      remaining: (json['remaining'] is num
          ? (json['remaining'] as num).toInt()
          : int.tryParse('${json['remaining']}') ?? 0),
      message: (json['message'] ?? '').toString(),
    );
  }

  @override
  String toString() {
    return 'AiAnalysisUsage(plan: $plan, isUnlimited: $isUnlimited, used: $used, limit: $limit, remaining: $remaining, message: $message)';
  }
}
