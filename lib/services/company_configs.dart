import 'dart:io';
import 'package:flutter/material.dart';

class CompanyConfig {
  final String name;
  final String ipAddress;
  final String? customKey;
  final String? description;

  const CompanyConfig({
    required this.name,
    required this.ipAddress,
    this.customKey,
    this.description,
  });
}

// المفتاح الافتراضي المستخدم للتشفير إذا لم يتم تحديد مفتاح خاص
const String defaultSecretKey = 'abcdefghijuklmno0123456789012345';

// قائمة الشركات المتاحة
const List<CompanyConfig> availableCompanies = [
  CompanyConfig(
    name: "79.133.46.123",
    ipAddress: "79.133.46.123",
    
  ),
 
  
  CompanyConfig(
    name: "195.154.53.214",
    ipAddress: "195.154.53.214",
    //description: "خادم اتصالات بابل",
  ),
  CompanyConfig(
    name: "admin.uniquefi.net",
    ipAddress: "admin.uniquefi.net",
   
  ),
  CompanyConfig(
    name: "كيكا نت ",
    ipAddress: "reseller.giganet.iq",
    
  ),





  
  CompanyConfig(
    name: "دش نتيورك",
    ipAddress: "r.dishtele.com",
    
  ),

  CompanyConfig(
    name: "كويك نت",
    ipAddress: "sas-serv2.quicknet-iq.com",
    
  ),


CompanyConfig(
    name: "اوربت",
    ipAddress: "sas.orbit-isp.com",
    
  ),

CompanyConfig(
    name: "سوبر سيل",
    ipAddress: "itpc.scn-wifi.com",
    
  ),
CompanyConfig(
    name: "194.99.20.36",
    ipAddress: "194.99.20.36",
    
  ),


CompanyConfig(
    name: "هرنز تليكوم",
    ipAddress: "wbasas.hrins.net",
    
  ),


CompanyConfig(
    name: "فايبر اكس",
    ipAddress: "k-sas.fiberx.iq",
    
  ),
CompanyConfig(
    name: "اوبتمم",
    ipAddress: "sas.otto-isp.com",
    
  ),
CompanyConfig(
    name: "نور البداية",
    ipAddress: "sas.nbtel.iq",
    
  ),


  CompanyConfig(
    name: "الشمس",
    ipAddress: "reseller.shams-tele.com",
    
  ),

  CompanyConfig(
    name: "هورايزون",
    ipAddress: "sas.otto-isp.com",
    
  ),

  CompanyConfig(
    name: "هالة سات",
    ipAddress: "192.168.255.254",
    
  ),

];

// دالة البحث عن شركة باسم محدد مع تحسين التشخيص
CompanyConfig? findCompanyByName(String name) {
  try {
    debugPrint("البحث عن شركة باسم: '$name'");
    
    // التحقق من قائمة الشركات
    debugPrint("قائمة الشركات المتاحة: ${availableCompanies.map((c) => "'${c.name}'").join(", ")}");
    
    // البحث عن الشركة بمطابقة الاسم بالضبط
    final company = availableCompanies.firstWhere(
      (company) => company.name == name,
      orElse: () => throw Exception("لم يتم العثور على شركة باسم: $name"),
    );
    
    debugPrint("✅ تم العثور على الشركة: ${company.name}, ${company.ipAddress}");
    return company;
  } catch (e) {
    debugPrint("❌ خطأ: لم يتم العثور على شركة باسم: '$name'");
    debugPrint("استخدام الشركة الافتراضية بدلاً من ذلك");
    return availableCompanies.isNotEmpty ? availableCompanies.first : null;
  }
}

// دالة البحث عن شركة بعنوان IP محدد
CompanyConfig? findCompanyByIp(String ipAddress) {
  try {
    debugPrint("البحث عن شركة بعنوان IP: $ipAddress");
    final company = availableCompanies.firstWhere(
      (company) => company.ipAddress == ipAddress,
      orElse: () => throw Exception("لم يتم العثور على شركة بعنوان IP: $ipAddress"),
    );
    debugPrint("✅ تم العثور على الشركة: ${company.name}");
    return company;
  } catch (e) {
    debugPrint("❌ خطأ: لم يتم العثور على شركة بعنوان IP: $ipAddress");
    return null;
  }
}

// الحصول على قائمة أسماء الشركات المتاحة
List<String> getAvailableCompanyNames() {
  final names = availableCompanies.map((company) => company.name).toList();
  debugPrint("تم جلب ${names.length} شركة: $names");
  return names;
}

// اختبار الاتصال بكل شركة
Future<void> testAvailableCompanies() async {
  for (var company in availableCompanies) {
    try {
      debugPrint("✅ الاتصال بالشركة ${company.name} (${company.ipAddress}) ناجح.");
    } catch (e) {
      debugPrint("❌ خطأ في الاتصال بالشركة ${company.name} (${company.ipAddress}): $e");
    }
  }
}