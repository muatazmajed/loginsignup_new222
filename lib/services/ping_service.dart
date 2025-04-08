import 'dart:async';
import 'package:dart_ping/dart_ping.dart';

class PingService {
  Future<int> pingHost(String host) async {
    try {
      final ping = Ping(host, count: 1);
      final response = await ping.stream.firstWhere(
        (event) => event.response != null, // التأكد من أن هناك استجابة
        orElse: () => PingData(response: null), // التعامل مع الخطأ عند عدم الاستجابة
      );

      if (response.error == null && response.response != null && response.response!.time != null) {
        return response.response!.time!.inMilliseconds; // إرجاع زمن البنق بالمللي ثانية
      } else {
        return -1; // فشل الاتصال
      }
    } catch (e) {
      return -1; // خطأ أثناء العملية
    }
  }
}
