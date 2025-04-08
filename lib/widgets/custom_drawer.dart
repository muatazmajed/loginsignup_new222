import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class CustomDrawer extends StatelessWidget {
  // بيانات المستخدم
  final String userName;
  final String userRole;
  final String userEmail;
  final String? userAvatarUrl;
  
  // بيانات المستخدمين
  final int onlineUsers;
  final int totalUsers;
  final int offlineUsers;
  
  // التنقل والإعدادات
  final int selectedIndex;
  final Function(int) onNavigate;
  final VoidCallback onLogout;
  final VoidCallback onAboutTap;
  final VoidCallback onSettingsTap; // سنحتفظ بها في المعاملات ولكن لن نستخدمها
  
  // بيانات السرعة
  final int facebookPing;
  final int googlePing;
  final int tiktokPing;
  
  // معلومات إضافية
  final String extraInfo;
  
  // ألوان التطبيق
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color cardColor;
  final Color textColor;

  const CustomDrawer({
    Key? key,
    required this.userName,
    required this.userRole,
    required this.userEmail,
    this.userAvatarUrl,
    required this.onlineUsers,
    required this.totalUsers,
    required this.offlineUsers,
    required this.selectedIndex,
    required this.onNavigate,
    required this.onLogout,
    required this.onAboutTap,
    required this.onSettingsTap,
    required this.facebookPing,
    required this.googlePing,
    required this.tiktokPing,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.textColor, 
    required this.extraInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        bottomLeft: Radius.circular(20),
      ),
      child: Drawer(
        backgroundColor: Colors.transparent,
        width: size.width * 0.78,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header section with user info
              _buildModernHeader(size),
              
              // Main menu content
              Expanded(
                child: _buildMainContent(size),
              ),
              
              // Logout button at the bottom
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  // Modern header with user info and stats
  Widget _buildModernHeader(Size size) {
    final double avatarSize = size.width * 0.16;
    
    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          // User info with avatar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                height: avatarSize,
                width: avatarSize,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: userAvatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(avatarSize / 2),
                        child: Image.network(
                          userAvatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: avatarSize * 0.4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: avatarSize * 0.4,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              
              // User details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userRole,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    if (userEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // User stats
          _buildUserStats(size),
        ],
      ),
    );
  }
  
  // User stats in a modern layout
  Widget _buildUserStats(Size size) {
    // Calculate percentage
    final double percentage = totalUsers > 0 ? onlineUsers / totalUsers : 0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Online users
          _buildStatItem(
            icon: Icons.person,
            title: "متصل",
            count: onlineUsers,
            color: secondaryColor,
          ),
          
          // Total users with progress
          Column(
            children: [
              CircularPercentIndicator(
                radius: 22,
                lineWidth: 4,
                percent: percentage,
                center: Text(
                  "${(percentage * 100).toInt()}%",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                progressColor: secondaryColor,
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 4),
              Text(
                "المجموع",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
              Text(
                "$totalUsers",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // Offline users
          _buildStatItem(
            icon: Icons.person_off,
            title: "منتهي",
            count: offlineUsers,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  // Individual stat item
  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
        Text(
          "$count",
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Main scrollable content
  Widget _buildMainContent(Size size) {
    return Container(
      color: backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server info card
            _buildInfoCard(size),
            const SizedBox(height: 20),
            
            // Main navigation menu
            _buildMenuSection("لوحة التحكم", [
              MenuItem(
                index: 0,
                icon: Icons.dashboard_rounded,
                title: "الرئيسية",
              ),
            ]),
            
            const SizedBox(height: 16),
            
            _buildMenuSection("إدارة المستخدمين", [
              MenuItem(
                index: 2,
                icon: Icons.people,
                title: "جميع المستخدمين",
                badge: totalUsers,
                badgeColor: primaryColor,
              ),
              MenuItem(
                index: 1,
                icon: Icons.person,
                title: "المستخدمون المتصلون",
                badge: onlineUsers,
                badgeColor: secondaryColor,
              ),
              MenuItem(
                index: 3,
                icon: Icons.warning_amber_rounded,
                title: "المنتهي اشتراكهم",
                badge: offlineUsers,
                badgeColor: Colors.red[400],
              ),
            ]),
            
            const SizedBox(height: 16),
            
            _buildMenuSection("الأدوات", [
              MenuItem(
                index: 4,
                icon: Icons.speed,
                title: "اختبار سرعة الإنترنت",
              ),
            ]),
            
            const SizedBox(height: 16),
            
            // Network Status Section
            _buildNetworkStatusCard(),
            
            const SizedBox(height: 16),
            
            // System info
            _buildSystemInfoCard(size),
            
            // إضافة مساحة في الأسفل
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  // Server info card
  Widget _buildInfoCard(Size size) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.business,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "معلومات الخادم",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  extraInfo,
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Menu section with title and items
  Widget _buildMenuSection(String title, List<MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _buildMenuItem(item)).toList(),
      ],
    );
  }
  
  // Menu item widget
  Widget _buildMenuItem(MenuItem item) {
    final bool isSelected = selectedIndex == item.index;
    
    return InkWell(
      onTap: () => onNavigate(item.index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: primaryColor.withOpacity(0.3), width: 1) 
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? primaryColor.withOpacity(0.15) 
                    : surfaceColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                color: isSelected ? primaryColor : textColor.withOpacity(0.6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: isSelected ? primaryColor : textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (item.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.badgeColor ?? primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${item.badge}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Network status card
  Widget _buildNetworkStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wifi,
                color: primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "حالة الشبكة",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNetworkIndicator("فيسبوك", facebookPing, Icons.facebook),
              _buildNetworkIndicator("جوجل", googlePing, Icons.search),
              _buildNetworkIndicator("تيك توك", tiktokPing, Icons.music_video),
            ],
          ),
        ],
      ),
    );
  }
  
  // Network indicator
  Widget _buildNetworkIndicator(String name, int ping, IconData icon) {
    // تحديد حالة السرعة واللون
    String status;
    Color color;
    
    if (ping < 0) {
      status = "غير متصل";
      color = Colors.red;
    } else if (ping < 100) {
      status = "ممتاز";
      color = secondaryColor;
    } else if (ping < 200) {
      status = "جيد";
      color = accentColor;
    } else {
      status = "بطيء";
      color = Colors.red;
    }
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ping >= 0 ? "$ping ms" : "--",
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          status,
          style: TextStyle(
            color: textColor.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  // System info card
  Widget _buildSystemInfoCard(Size size) {
    final List<String> parts = extraInfo.split(' - ');
    final String company = parts[0];
    final String server = parts.length > 1 ? parts[1] : "";
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "معلومات النظام",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow("الشركة", company),
          _buildInfoRow("الخادم", server),
          _buildInfoRow("الإصدار", "1.0.0"),
        ],
      ),
    );
  }
  
  // Info row for system info
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  // Logout button (تحسين حجم ومظهر زر تسجيل الخروج)
  Widget _buildLogoutButton() {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text(
            "تسجيل الخروج",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

// Helper class for menu items
class MenuItem {
  final int index;
  final IconData icon;
  final String title;
  final int? badge;
  final Color? badgeColor;
  
  MenuItem({
    required this.index,
    required this.icon,
    required this.title,
    this.badge,
    this.badgeColor,
  });
}