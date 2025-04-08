// services/global_company.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'company_configs.dart';

class GlobalCompany {
  // الشركة المحددة حالياً (متغير ثابت)
  static CompanyConfig? _selectedCompany;
  
  // تعيين الشركة
  static void setCompany(CompanyConfig company) {
    _selectedCompany = company;
    debugPrint("✅ تم تعيين الشركة العالمية: ${company.name}, IP: ${company.ipAddress}");
  }
  
  // الحصول على الشركة المختارة
  static CompanyConfig getCompany() {
    if (_selectedCompany == null) {
      debugPrint("⚠️ لم يتم تحديد شركة عالمية، استخدام الشركة الأولى");
      return availableCompanies.first;
    }
    debugPrint("📌 استخدام الشركة العالمية: ${_selectedCompany!.name}, IP: ${_selectedCompany!.ipAddress}");
    return _selectedCompany!;
  }
  
  // التحقق مما إذا كانت الشركة محددة
  static bool isCompanySet() {
    return _selectedCompany != null;
  }
  
  // تحميل الشركة المحفوظة
  static Future<void> loadSavedCompany() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCompanyName = prefs.getString('selected_company');
      
      debugPrint("محاولة تحميل الشركة المحفوظة: $savedCompanyName");
      
      if (savedCompanyName != null && savedCompanyName.isNotEmpty) {
        final company = findCompanyByName(savedCompanyName);
        if (company != null) {
          _selectedCompany = company;
          debugPrint("✅ تم تحميل الشركة المحفوظة: ${company.name}, IP: ${company.ipAddress}");
        } else {
          debugPrint("⚠️ لم يتم العثور على الشركة المحفوظة: $savedCompanyName");
        }
      } else {
        debugPrint("⚠️ لا توجد شركة محفوظة");
      }
    } catch (e) {
      debugPrint("❌ خطأ في تحميل الشركة المحفوظة: $e");
    }
  }
  
  // حفظ الشركة المحددة
  static Future<void> saveCompany(String companyName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_company', companyName);
      debugPrint("✅ تم حفظ الشركة: $companyName");
    } catch (e) {
      debugPrint("❌ خطأ في حفظ الشركة: $e");
    }
  }
  
  // الحصول على اسم الشركة الحالية
  static String getCompanyName() {
    return _selectedCompany?.name ?? availableCompanies.first.name;
  }
}