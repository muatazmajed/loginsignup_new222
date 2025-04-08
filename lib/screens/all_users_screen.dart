import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/global_company.dart';
import '../services/database_service.dart';
import 'user_details_screen.dart';

class AllUsersScreen extends StatefulWidget {
  final String token;
  final List? cachedData;

  const AllUsersScreen({Key? key, required this.token, required this.cachedData}) : super(key: key);

  @override
  _AllUsersScreenState createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> with SingleTickerProviderStateMixin {
  late ApiService _apiService;
  final TextEditingController _searchController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _userFuture;
  List<Map<String, dynamic>> _allUsers = [];
  final _scrollController = ScrollController();
  bool _isLoading = false;
  bool _usingCachedData = false;
  late TabController _tabController;
  
  // ألوان التطبيق المحدثة
  final _primaryColor = Color(0xFF3949AB); // indigo.shade600 (أكثر عصرية)
  final _primaryLightColor = Color(0xFFE8EAF6); // indigo.shade50
  final _primaryDarkColor = Color(0xFF283593); // indigo.shade800
  final _accentColor = Color(0xFFFFB300); // amber.shade600 (مشرق أكثر)
  final _backgroundColor = Color(0xFFF7F9FC); // أفتح قليلاً من gray.shade50
  final _darkTextColor = Color(0xFF424242); // gray.shade800
  final _cardColor = Colors.white;
  final _errorColor = Color(0xFFEF5350); // red.shade400
  final _successColor = Color(0xFF66BB6A); // green.shade400
  final _warningColor = Color(0xFFFFA726); // orange.shade400

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initApiService();
    _initializeData();
  }

  void _initializeData() {
    if (widget.cachedData != null && widget.cachedData!.isNotEmpty) {
      _userFuture = _loadCachedData();
    } else {
      _userFuture = _fetchAllUsers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _initApiService() {
    try {
      if (GlobalCompany.isCompanySet()) {
        debugPrint("استخدام الشركة العالمية: ${GlobalCompany.getCompanyName()}");
        _apiService = ApiService.fromCompanyConfig(GlobalCompany.getCompany());
      } else {
        debugPrint("الشركة العالمية غير محددة، استخدام الافتراضية");
        _apiService = ApiService(serverDomain: '');
      }
      
      _apiService.printServiceInfo();
    } catch (e) {
      debugPrint("خطأ في تهيئة ApiService: $e");
      _apiService = ApiService(serverDomain: '');
    }
  }

  Future<List<Map<String, dynamic>>> _loadCachedData() async {
    debugPrint("تحميل البيانات المخزنة مسبقًا...");
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> users = [];
      
      for (var item in widget.cachedData!) {
        if (item is Map) {
          Map<String, dynamic> user = {};
          item.forEach((key, value) {
            if (key is String) {
              user[key] = value;
            }
          });
          
          users.add(user);
        }
      }
      
      debugPrint("تم تحميل ${users.length} مستخدم من البيانات المخزنة");
      
      setState(() {
        _allUsers = users;
        _usingCachedData = true;
        _isLoading = false;
      });
      
      return users;
    } catch (e) {
      debugPrint("خطأ أثناء تحميل البيانات المخزنة: $e");
      setState(() {
        _isLoading = false;
        _usingCachedData = false;
      });
      
      return _fetchAllUsers();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllUsers() async {
    setState(() {
      _isLoading = true;
      _usingCachedData = false;
    });
    
    try {
      debugPrint("بدء جلب جميع المستخدمين...");
      debugPrint("استخدام التوكن: ${widget.token.length > 20 ? widget.token.substring(0, 20) + '...' : widget.token}");
      
      List<Map<String, dynamic>> users = await _apiService.getAllUsers(widget.token);
      debugPrint("تم جلب ${users.length} مستخدم بنجاح");
      
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
      return users;
    } catch (e) {
      debugPrint("خطأ أثناء جلب البيانات: $e");
      setState(() {
        _isLoading = false;
      });
      return [];
    }
  }

  Future<void> _refreshData() async {
    debugPrint("إعادة تحميل بيانات المستخدمين...");
    
    _initApiService();
    
    setState(() {
      _userFuture = _fetchAllUsers();
    });
  }

  List<Map<String, dynamic>> _filterUsers(String query) {
    return _allUsers.where((user) {
      final username = user['username']?.toLowerCase() ?? '';
      final fullName =
          "${user['firstname'] ?? ''} ${user['lastname'] ?? ''}".trim().toLowerCase();
      return username.contains(query.toLowerCase()) || fullName.contains(query.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> _filterUsersByStatus(List<Map<String, dynamic>> users, String status) {
    switch (status) {
      case 'active':
        return users.where((user) {
          final statusText = _getStatusText(user['expiration']);
          return statusText == "نشط";
        }).toList();
      case 'expiring':
        return users.where((user) {
          final statusText = _getStatusText(user['expiration']);
          return statusText == "ينتهي قريباً";
        }).toList();
      case 'expired':
        return users.where((user) {
          final statusText = _getStatusText(user['expiration']);
          return statusText == "منتهي";
        }).toList();
      default:
        return users;
    }
  }

  Color _getUserStatus(String? expirationDate) {
    if (expirationDate == null || expirationDate.isEmpty) return Colors.grey;

    try {
      DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expirationDate);
      DateTime now = DateTime.now();
      int daysRemaining = expiryDate.difference(now).inDays;
      
      if (now.isAfter(expiryDate)) {
        return _errorColor; // منتهي
      } else if (daysRemaining <= 7) {
        return _warningColor; // ينتهي قريباً
      } else {
        return _successColor; // نشط
      }
    } catch (e) {
      return Colors.grey.shade400;
    }
  }

  String _getStatusText(String? expirationDate) {
    if (expirationDate == null || expirationDate.isEmpty) return "غير محدد";

    try {
      DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expirationDate);
      DateTime now = DateTime.now();
      int daysRemaining = expiryDate.difference(now).inDays;
      
      if (now.isAfter(expiryDate)) {
        return "منتهي";
      } else if (daysRemaining <= 7) {
        return "ينتهي قريباً";
      } else {
        return "نشط";
      }
    } catch (e) {
      return "غير محدد";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _buildNestedUI(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildNestedUI() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildAppBar(innerBoxIsScrolled),
        ];
      },
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatsCards(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserListWithStatus('all'),
                _buildUserListWithStatus('active'),
                _buildUserListWithStatus('expired'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: _primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryColor, _primaryDarkColor],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.people_alt_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "إدارة المشتركين",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Container(
            margin: EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: _accentColor,
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people, size: 20),
                        SizedBox(width: 6),
                        Text("الكل"),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, size: 20),
                        SizedBox(width: 6),
                        Text("نشط"),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber, size: 20),
                        SizedBox(width: 6),
                        Text("منتهي"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.sort, color: Colors.white, size: 22),
          ),
          tooltip: 'ترتيب',
          onPressed: _showSortOptions,
        ),
        SizedBox(width: 10),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _refreshData,
      backgroundColor: _accentColor,
      child: Icon(Icons.refresh, color: Colors.white),
      tooltip: 'تحديث البيانات',
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: _darkTextColor, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.search, color: _primaryColor, size: 22),
          ),
          hintText: "بحث عن مشترك...",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 16, color: Colors.grey.shade700),
                ),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                  });
                },
              )
            : null,
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildStatsCards() {
    // حساب عدد المشتركين لكل حالة
    final activeUsers = _allUsers.where((user) => _getStatusText(user['expiration']) == "نشط").length;
    final expiringUsers = _allUsers.where((user) => _getStatusText(user['expiration']) == "ينتهي قريباً").length;
    final expiredUsers = _allUsers.where((user) => _getStatusText(user['expiration']) == "منتهي").length;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.verified_user,
            color: _successColor,
            title: "نشط",
            count: activeUsers,
          ),
          _buildStatCard(
            icon: Icons.timer,
            color: _warningColor,
            title: "ينتهي قريباً",
            count: expiringUsers,
          ),
          _buildStatCard(
            icon: Icons.cancel,
            color: _errorColor,
            title: "منتهي",
            count: expiredUsers,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required int count,
  }) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 5),
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              spreadRadius: 1,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _darkTextColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "$count",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 50,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Row(
              children: [
                Icon(Icons.sort, color: _primaryColor, size: 24),
                SizedBox(width: 14),
                Text(
                  "ترتيب المشتركين",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
            Divider(height: 28, thickness: 1),
            _buildSortOption(
              icon: Icons.calendar_today,
              title: "تاريخ الانتهاء",
              subtitle: "ترتيب من الأقرب للأبعد",
              onTap: () {
                _sortUsers('expiration');
                Navigator.pop(context);
              },
            ),
            _buildSortOption(
              icon: Icons.sort_by_alpha,
              title: "الاسم",
              subtitle: "ترتيب أبجدي للأسماء",
              onTap: () {
                _sortUsers('name');
                Navigator.pop(context);
              },
            ),
            _buildSortOption(
              icon: Icons.verified_user,
              title: "الحالة",
              subtitle: "ترتيب حسب الحالة",
              onTap: () {
                _sortUsers('status');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _primaryLightColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _darkTextColor,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: _primaryColor),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    );
  }

  void _sortUsers(String method) {
    setState(() {
      if (method == 'name') {
        _allUsers.sort((a, b) {
          final nameA = "${a['firstname'] ?? ''} ${a['lastname'] ?? ''}".trim();
          final nameB = "${b['firstname'] ?? ''} ${b['lastname'] ?? ''}".trim();
          return nameA.compareTo(nameB);
        });
      } else if (method == 'expiration') {
        _allUsers.sort((a, b) {
          try {
            final dateA = a['expiration'] != null && a['expiration'].toString().isNotEmpty
                ? DateFormat("yyyy-MM-dd HH:mm:ss").parse(a['expiration'])
                : DateTime(2100);
            final dateB = b['expiration'] != null && b['expiration'].toString().isNotEmpty
                ? DateFormat("yyyy-MM-dd HH:mm:ss").parse(b['expiration'])
                : DateTime(2100);
            return dateA.compareTo(dateB);
          } catch (e) {
            return 0;
          }
        });
      } else if (method == 'status') {
        _allUsers.sort((a, b) {
          final statusA = _getStatusText(a['expiration']);
          final statusB = _getStatusText(b['expiration']);
          // ترتيب: نشط، ينتهي قريباً، منتهي، غير محدد
          final order = {
            "نشط": 0,
            "ينتهي قريباً": 1,
            "منتهي": 2,
            "غير محدد": 3,
          };
          return (order[statusA] ?? 4).compareTo(order[statusB] ?? 4);
        });
      }
    });
    
    _showSnackBar("تم ترتيب المشتركين بنجاح", _successColor);
  }

  Widget _buildUserListWithStatus(String status) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _userFuture,
      builder: (context, snapshot) {
        // عرض مؤشر التحميل عندما يكون جاري التحميل
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return _buildLoadingView();
        } 
        // التحقق من وجود أخطاء أو بيانات فارغة
        else if (snapshot.hasError) {
          return _buildErrorMessage("خطأ أثناء جلب البيانات: ${snapshot.error}");
        } 
        // التحقق من وجود بيانات
        else if (_allUsers.isEmpty && !_isLoading) {
          // إذا كان من المفترض استخدام بيانات مخزنة ولكنها غير موجودة
          if (widget.cachedData != null && widget.cachedData!.isEmpty) {
            return _buildEmptyState("لا توجد بيانات متاحة");
          }
          // إذا فشل جلب البيانات من API
          return _buildEmptyState("لا يوجد مشتركين بعد");
        }

        // تصفية المستخدمين حسب البحث
        var filteredUsers = _filterUsers(_searchController.text);
        
        // تصفية حسب الحالة
        if (status != 'all') {
          if (status == 'active') {
            filteredUsers = _filterUsersByStatus(filteredUsers, 'active');
          } else if (status == 'expired') {
            filteredUsers = _filterUsersByStatus(filteredUsers, 'expired');
          }
        }
        
        if (filteredUsers.isEmpty) {
          return _buildNoResultsFound();
        }
        
        return _buildUserList(filteredUsers);
      },
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    return ListView.builder(
      physics: BouncingScrollPhysics(),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final statusText = _getStatusText(user['expiration']);
        
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, 0, 0),
          transformAlignment: Alignment.center,
          margin: EdgeInsets.only(bottom: 12),
          child: _buildUserCard(user, statusText),
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, String statusText) {
    final statusColor = _getUserStatus(user['expiration']);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserDetailsScreen(
              user: user,
              token: widget.token,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              spreadRadius: 1,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildAvatar(user),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${user['firstname'] ?? ''} ${user['lastname'] ?? ''}".trim().isEmpty
                              ? "غير معروف"
                              : "${user['firstname'] ?? ''} ${user['lastname'] ?? ''}".trim(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _darkTextColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "@${user['username'] ?? 'غير معروف'}",
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        if (user['phone'] != null && user['phone'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.phone, size: 14, color: _successColor),
                                SizedBox(width: 4),
                                Text(
                                  user['phone'],
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoItem(
                    Icons.calendar_today_rounded,
                    "تاريخ الانتهاء",
                    _formatExpiryDate(user['expiration']),
                  ),
                  _buildInfoItem(
                    Icons.supervisor_account_rounded,
                    "نوع الحساب",
                    user['userType'] ?? "قياسي",
                  ),
                ],
              ),
            ),
            if (user['phone'] != null && user['phone'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildReminderButton(user),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app, 
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "اضغط لعرض التفاصيل الكاملة",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> user) {
    final fullName = "${user['firstname'] ?? ''} ${user['lastname'] ?? ''}".trim();
    final username = user['username'] ?? "غير معروف";
    final initials = _getInitials(fullName, username);
    final statusColor = _getUserStatus(user['expiration']);
    
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryLightColor, _primaryColor.withOpacity(0.7)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: Colors.transparent,
            radius: 28,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius:
                  4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: statusColor,
              radius: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryLightColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _primaryColor),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _darkTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderButton(Map<String, dynamic> user) {
    return ElevatedButton.icon(
      onPressed: () => _sendPaymentReminder(user),
      icon: const Icon(Icons.notification_important_rounded, size: 18),
      label: const Text("إرسال تنبيه للتسديد"),
      style: ElevatedButton.styleFrom(
        backgroundColor: _errorColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  String _formatExpiryDate(String? expiryDate) {
    if (expiryDate == null || expiryDate.isEmpty) return "—";
    
    try {
      DateTime expDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expiryDate);
      return DateFormat("yyyy/MM/dd").format(expDate);
    } catch (e) {
      return "—";
    }
  }

  String _getInitials(String fullName, String username) {
    if (fullName.isNotEmpty) {
      List<String> nameParts = fullName.split(' ');
      if (nameParts.length > 1 && nameParts[0].isNotEmpty && nameParts[1].isNotEmpty) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else if (nameParts.length == 1 && nameParts[0].isNotEmpty) {
        return nameParts[0][0].toUpperCase();
      }
    }
    
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  Future<void> _sendPaymentReminder(Map<String, dynamic> user) async {
    final String phoneNumber = user['phone'] ?? '';
    if (phoneNumber.isEmpty) {
      _showSnackBar("رقم الهاتف غير متوفر للمستخدم", _errorColor);
      return;
    }

    final String fullName = "${user['firstname'] ?? ''} ${user['lastname'] ?? ''}".trim();
    final String username = user['username'] ?? "المستخدم";
    final String displayName = fullName.isNotEmpty ? fullName : username;
    
    // تنظيف رقم الهاتف
    String cleanedPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    cleanedPhone = cleanedPhone.replaceAll(RegExp(r'[+()-]'), '');
    
    // تنسيق رقم الهاتف للعراق
    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '964' + cleanedPhone.substring(1);
    } else if (!cleanedPhone.startsWith('964')) {
      cleanedPhone = '964' + cleanedPhone;
    }

    // إنشاء رسالة التذكير
    final String message = 'عزيزي المشترك ${displayName}،\n\n'
        'تحية طيبة،\n'
        'نود تذكيركم بضرورة تسديد المبلغ المستحق عليكم من ديون سابقة لتجنب توقف خدمة الإنترنت. يرجى المبادرة بالتسديد في أقرب وقت ممكن وذلك لضمان استمرار تقديم الخدمة لكم بشكل سلس.\n\n'
        'للاستفسار أو التسديد، يرجى التواصل معنا مباشرة على هذا الرقم أو زيارتنا.\n\n'
        'مع خالص الشكر والتقدير';

    // إنشاء رابط واتساب
    final Uri whatsappUri = Uri.parse(
      "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}"
    );
    
    try {
      // محاولة فتح واتساب
      await launchUrl(
        whatsappUri, 
        mode: LaunchMode.externalApplication,
      );
      
      _showSnackBar("تم فتح واتساب لإرسال تنبيه التسديد", _successColor);
    } catch (e) {
      debugPrint("خطأ في فتح واتساب: $e");
      
      // محاولة استخدام الرابط المباشر إذا فشلت المحاولة الأولى
      try {
        final Uri directUri = Uri.parse(
          "whatsapp://send?phone=$cleanedPhone&text=${Uri.encodeComponent(message)}"
        );
        await launchUrl(directUri, mode: LaunchMode.externalNonBrowserApplication);
      } catch (e2) {
        _showSnackBar("تعذر فتح واتساب. تأكد من تثبيت التطبيق", _errorColor);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == _errorColor ? Icons.error : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'موافق',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryLightColor,
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 20),
          Text(
            "جاري تحميل بيانات المشتركين...",
            style: TextStyle(
              color: _primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Center(
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: _errorColor, size: 48),
            ),
            SizedBox(height: 20),
            Text(
              "حدث خطأ",
              style: TextStyle(
                color: _darkTextColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              message, 
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text("إعادة المحاولة"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState([String? message]) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(30),
        margin: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryLightColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_off, color: _primaryColor, size: 48),
            ),
            SizedBox(height: 24),
            Text(
              message ?? "لا يوجد مشتركين بعد",
              style: TextStyle(
                color: _darkTextColor, 
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              "سيظهر المشتركون هنا عند إضافتهم",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (!_usingCachedData) ...[
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: Icon(Icons.refresh),
                label: Text("تحديث البيانات"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(30),
        margin: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryLightColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off, color: _primaryColor, size: 48),
            ),
            SizedBox(height: 24),
            Text(
              "لا توجد نتائج مطابقة",
              style: TextStyle(
                color: _darkTextColor, 
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              "جرّب كلمات بحث أخرى",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                });
              },
              icon: Icon(Icons.clear),
              label: Text("مسح البحث"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}