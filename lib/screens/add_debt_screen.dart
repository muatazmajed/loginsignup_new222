import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/debt_model.dart';
import '../services/database_service.dart';

class AddDebtScreen extends StatefulWidget {
  final String token;
  final String? existingUsername;
  final bool isAddingToExisting;
  final int? existingUserId; // إضافة معرف المستخدم الموجود كمعلمة

  const AddDebtScreen({
    Key? key,
    required this.token,
    this.existingUsername,
    this.isAddingToExisting = false,
    this.existingUserId,
  }) : super(key: key);

  @override
  _AddDebtScreenState createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService.instance;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(Duration(days: 30));

  bool _isLoading = false;
  bool _isPhoneNumberRequired = true;
  int _userId = 0;

  final Color _primaryColor = const Color(0xFFFF6B35);
  final Color _secondaryColor = const Color(0xFFF9F2E7);
  final Color _accentColor = const Color(0xFF2EC4B6);
  final Color _backgroundColor = Colors.white;
  final Color _textColor = Colors.black87;

  @override
  void initState() {
    super.initState();

    // استخدام معرف المستخدم الموجود إذا تم تمريره
    if (widget.existingUserId != null) {
      _userId = widget.existingUserId!;
    }

    if (widget.existingUsername != null) {
      _usernameController.text = widget.existingUsername!;

      if (widget.isAddingToExisting) {
        _loadUserDetails();
      }
    }
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // استخدام معرف المستخدم للبحث إذا كان متاحاً
      List<DebtModel> debts;
      if (_userId > 0) {
        debts = await _databaseService.getDebtsByUserId(_userId);
      } else {
        debts = await _databaseService.getDebtsByUsername(widget.existingUsername!);
        // حفظ معرف المستخدم من الديون التي تم العثور عليها
        if (debts.isNotEmpty && debts.first.userId != null) {
          _userId = debts.first.userId!;
        }
      }

      if (debts.isNotEmpty) {
        // استخدم البيانات من أحدث دين (للحصول على أحدث معلومات الاتصال)
        debts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latestDebt = debts.first;
        
        setState(() {
          if (latestDebt.phoneNumber != null && latestDebt.phoneNumber!.isNotEmpty) {
            _phoneController.text = latestDebt.phoneNumber!;
            _isPhoneNumberRequired = false;
          }
        });
      }
    } catch (e) {
      print("خطأ في تحميل تفاصيل المستخدم: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: _textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _accentColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // إذا كان المستخدم موجودًا ولكن معرف المستخدم لا يزال 0، احصل على المعرف الصحيح
      if (_userId == 0 && widget.existingUsername != null) {
        _userId = await _databaseService.getUserIdByUsername(widget.existingUsername!);
      }
      
      // إنشاء نموذج الدين
      final debt = DebtModel(
        id: null,
        userId: _userId,
        username: _usernameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        amount: double.parse(_amountController.text),
        dueDate: _dueDate,
        createdAt: DateTime.now(),
        isPaid: false,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      // حفظ الدين
      await _databaseService.addDebt(debt);

      _showSuccessSnackBar(widget.isAddingToExisting
          ? "تم إضافة الدين إلى المستخدم الحالي بنجاح"
          : "تم إضافة الدين الجديد بنجاح");

      Navigator.pop(context, true);
    } catch (e) {
      print("خطأ في حفظ الدين: $e");
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar("حدث خطأ أثناء حفظ الدين");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.isAddingToExisting
              ? "إضافة إلى دين موجود"
              : "إضافة دين جديد",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username field (read-only if adding to existing debt)
                    TextFormField(
                      controller: _usernameController,
                      readOnly: widget.isAddingToExisting,
                      decoration: InputDecoration(
                        labelText: "اسم المستخدم *",
                        hintText: "أدخل اسم المستخدم",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.person, color: _primaryColor),
                        filled: true,
                        fillColor: widget.isAddingToExisting
                            ? Colors.grey.shade200
                            : _secondaryColor,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "اسم المستخدم مطلوب";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Phone number field
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: "رقم الهاتف ${_isPhoneNumberRequired ? '*' : ''}",
                        hintText: "مثال: 07xxxxxxxx",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.phone, color: _primaryColor),
                        filled: true,
                        fillColor: _secondaryColor,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (_isPhoneNumberRequired && (value == null || value.trim().isEmpty)) {
                          return "رقم الهاتف مطلوب";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Amount field
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: "المبلغ *",
                        hintText: "أدخل المبلغ",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.attach_money, color: _primaryColor),
                        suffixText: "د.ع",
                        filled: true,
                        fillColor: _secondaryColor,
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "المبلغ مطلوب";
                        }
                        try {
                          final amount = double.parse(value);
                          if (amount <= 0) {
                            return "يجب أن يكون المبلغ أكبر من صفر";
                          }
                        } catch (e) {
                          return "أدخل مبلغاً صحيحاً";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Due date field
                    GestureDetector(
                      onTap: () => _selectDueDate(context),
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: "تاريخ الاستحقاق *",
                            hintText: "اختر تاريخ الاستحقاق",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Icon(Icons.calendar_today, color: _primaryColor),
                            suffixIcon: Icon(Icons.arrow_drop_down, color: _primaryColor),
                            filled: true,
                            fillColor: _secondaryColor,
                          ),
                          controller: TextEditingController(
                            text: DateFormat('yyyy/MM/dd').format(_dueDate),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Notes field
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: "ملاحظات",
                        hintText: "أدخل أي ملاحظات إضافية (اختياري)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.note, color: _primaryColor),
                        filled: true,
                        fillColor: _secondaryColor,
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveDebt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          widget.isAddingToExisting
                              ? "إضافة إلى الدين الموجود"
                              : "حفظ الدين",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Info card for adding to existing debt
                    if (widget.isAddingToExisting) ...[
                      SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.amber.shade800),
                                SizedBox(width: 8),
                                Text(
                                  "معلومات هامة",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "سيتم إضافة هذا المبلغ كدين جديد مرتبط بنفس المستخدم. سيظهر في القائمة منفصلاً مع إظهار مؤشر يدل على وجود ديون متعددة للمستخدم.",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}