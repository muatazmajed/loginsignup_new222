import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../services/global_company.dart';

class OnlineUsersScreen extends StatefulWidget {
  final String token;
  final List cachedData;

  const OnlineUsersScreen({
    Key? key, 
    required this.token, 
    required this.cachedData,
  }) : super(key: key);

  @override
  _OnlineUsersScreenState createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen> with SingleTickerProviderStateMixin {
  // Services
  late ApiService _apiService;
  
  // Data
  Future<List<User>>? _onlineUsersFuture;
  List<User> _onlineUsers = [];
  
  // State flags
  bool _isRefreshing = false;
  bool _isFirstLoad = true;
  bool _isInitializing = true;
  bool _usingCachedData = false;
  
  // Animation
  late AnimationController _refreshIconController;
  
  // Theme colors
  final AppTheme _theme = AppTheme();

  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _initializeAndFetchData();
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    super.dispose();
  }

  /// Initialize ApiService and fetch data
  Future<void> _initializeAndFetchData() async {
    setState(() => _isInitializing = true);
    
    await _initApiService();
    
    if (widget.cachedData.isNotEmpty) {
      _loadCachedData();
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        setState(() {
          _onlineUsersFuture = _fetchOnlineUsers();
          _isInitializing = false;
        });
      }
    }
  }

  /// Initialize ApiService with global company
  Future<void> _initApiService() async {
    try {
      if (GlobalCompany.isCompanySet()) {
        debugPrint("Using global company: ${GlobalCompany.getCompanyName()}");
        _apiService = ApiService.fromCompanyConfig(GlobalCompany.getCompany());
      } else {
        debugPrint("Global company not set, using default");
        _apiService = ApiService(serverDomain: '');
      }
      
      _apiService.printServiceInfo();
    } catch (e) {
      debugPrint("Error initializing ApiService: $e");
      _apiService = ApiService(serverDomain: '');
    }
  }

  /// Load cached data from widget parameter
  void _loadCachedData() {
    try {
      List<User> users = widget.cachedData.map((data) => User.fromJson(data)).toList();
      
      users.sort((a, b) => a.username.compareTo(b.username));
      
      setState(() {
        _onlineUsers = users;
        _isInitializing = false;
        _usingCachedData = true;
        _onlineUsersFuture = Future.value(users);
      });
      
      debugPrint("Loaded ${users.length} users from cached data");
    } catch (e) {
      debugPrint("Error loading cached data: $e");
      setState(() {
        _onlineUsersFuture = _fetchOnlineUsers();
        _isInitializing = false;
      });
    }
  }

  /// Fetch online users from API
  Future<List<User>> _fetchOnlineUsers() async {
    setState(() {
      _isRefreshing = true;
      _usingCachedData = false;
    });
    
    _refreshIconController.repeat();
    
    try {
      if (_isFirstLoad) {
        await Future.delayed(const Duration(milliseconds: 300));
        _isFirstLoad = false;
      }
      
      List<Map<String, dynamic>> usersData = await _apiService.getOnlineUsers(widget.token);
      List<User> users = usersData.map((data) => User.fromJson(data)).toList();
      
      users.sort((a, b) => a.username.compareTo(b.username));
      
      if (mounted) {
        setState(() {
          _onlineUsers = users;
          _isRefreshing = false;
        });
      }
      
      _refreshIconController.stop();
      _refreshIconController.reset();
      
      return users;
    } catch (e) {
      debugPrint("Error fetching online users: $e");
      
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
      
      _refreshIconController.stop();
      _refreshIconController.reset();
      
      if (_onlineUsers.isNotEmpty) {
        setState(() => _usingCachedData = true);
        return _onlineUsers;
      }
      
      if (_isFirstLoad) {
        _isFirstLoad = false;
        await Future.delayed(const Duration(milliseconds: 1000));
        return _fetchOnlineUsers();
      }
      
      throw e;
    }
  }

  /// Open user IP in browser
  void _openUserIP(User user) async {
    if (user.ipAddress.isEmpty) {
      _showMessage('IP address not available for this user');
      return;
    }
    
    final url = Uri.parse('http://${user.ipAddress}');
    
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to open link: ${user.ipAddress}', isError: true);
      }
    }
  }
  
  /// Show message in snackbar
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? _theme.errorColor : _theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.backgroundColor,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _onlineUsersFuture = _fetchOnlineUsers());
        },
        color: _theme.primaryColor,
        backgroundColor: _theme.cardColor,
        displacement: 20,
        child: _buildPageContent(),
      ),
    );
  }

  /// Build the main content based on current state
  Widget _buildPageContent() {
    if (_isInitializing) {
      return _buildLoadingIndicator();
    }
    
    return FutureBuilder<List<User>>(
      future: _onlineUsersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_usingCachedData) {
          return _buildLoadingIndicator();
        } else if (snapshot.hasError && _onlineUsers.isEmpty) {
          return _buildErrorMessage(snapshot.error.toString());
        } else if (!snapshot.hasData && _onlineUsers.isEmpty) {
          return _buildEmptyState();
        }

        final users = _usingCachedData ? _onlineUsers : (snapshot.data ?? _onlineUsers);
        
        if (users.isEmpty) {
          return _buildEmptyState();
        }
        
        return _buildUserList(users);
      },
    );
  }

  /// Build app bar
  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi,
            color: _theme.cardColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            "Online Users",
            style: TextStyle(
              color: _theme.cardColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_theme.primaryColor, Color(0xFF1E40AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 2,
      centerTitle: true,
      toolbarHeight: 56,
      actions: [
        _buildRefreshButton(),
      ],
    );
  }

  /// Build the refresh button with indicators
  Widget _buildRefreshButton() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: Tween(begin: 0.0, end: 1.0).animate(_refreshIconController),
            child: IconButton(
              icon: Icon(Icons.refresh, color: _theme.cardColor, size: 22),
              onPressed: _isRefreshing 
                ? null 
                : () => setState(() => _onlineUsersFuture = _fetchOnlineUsers()),
              splashRadius: 24,
              tooltip: 'Refresh',
            ),
          ),
          if (_onlineUsers.isNotEmpty)
            Positioned(
              top: 10,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _theme.secondaryColor,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    "${_onlineUsers.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          if (_usingCachedData)
            Positioned(
              bottom: 10,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _theme.accentColor,
                  shape: BoxShape.circle,
                ),
                width: 8,
                height: 8,
              ),
            ),
        ],
      ),
    );
  }

  /// Build loading indicator
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: _theme.primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Loading users...",
            style: TextStyle(
              color: _theme.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _theme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.signal_wifi_off_rounded,
              size: 48,
              color: _theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No online users at the moment",
            style: TextStyle(
              color: _theme.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Pull down to refresh the list",
              style: TextStyle(
                color: _theme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          _buildButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onPressed: () => setState(() => _onlineUsersFuture = _fetchOnlineUsers()),
            backgroundColor: _theme.primaryColor,
          ),
        ],
      ),
    );
  }

  /// Build error message
  Widget _buildErrorMessage(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _theme.errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: _theme.errorColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Failed to fetch data",
            style: TextStyle(
              color: _theme.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Try again or check your internet connection",
              style: TextStyle(
                color: _theme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          _buildButton(
            icon: Icons.refresh_rounded,
            label: "Try Again",
            onPressed: () => setState(() => _onlineUsersFuture = _fetchOnlineUsers()),
            backgroundColor: _theme.primaryColor,
          ),
        ],
      ),
    );
  }

  /// Build generic button
  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
        minimumSize: const Size(120, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Build list of users
  Widget _buildUserList(List<User> users) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 30.0,
              child: FadeInAnimation(
                child: _buildUserCard(user),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build user card
  Widget _buildUserCard(User user) {
    // Calculate percentage for data usage visualization
    final int totalBytes = user.downloadBytes + user.uploadBytes;
    final double downloadPercentage = totalBytes > 0 ? user.downloadBytes / totalBytes : 0.5;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openUserIP(user),
          splashColor: _theme.primaryColor.withOpacity(0.1),
          highlightColor: _theme.primaryColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info section
                _buildUserInfo(user),
                const SizedBox(height: 12),
                
                // Data usage bar
                _buildDataUsageSection(user, downloadPercentage, totalBytes),
                
                // Usage details
                _buildUsageStats(user),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build user info section with avatar and ip
  Widget _buildUserInfo(User user) {
    return Row(
      children: [
        _buildUserAvatar(user),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.username,
                style: TextStyle(
                  color: _theme.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.language,
                    size: 12,
                    color: _theme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      user.ipAddress.isEmpty ? "IP not available" : user.ipAddress,
                      style: TextStyle(
                        color: _theme.textSecondaryColor,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _theme.backgroundColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.open_in_browser,
            size: 14,
            color: _theme.primaryColor,
          ),
        ),
      ],
    );
  }

  /// Build user avatar
  Widget _buildUserAvatar(User user) {
    final String initial = user.username.isNotEmpty ? user.username[0].toUpperCase() : "?";
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_theme.primaryColor, _theme.primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  /// Build data usage visualization section
  Widget _buildDataUsageSection(User user, double downloadPercentage, int totalBytes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Data Usage",
              style: TextStyle(
                color: _theme.textPrimaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            Text(
              "Total: ${_formatBytes(totalBytes)}",
              style: TextStyle(
                color: _theme.textSecondaryColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              // Download bar
              Expanded(
                flex: (downloadPercentage * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: _theme.secondaryColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(3),
                      bottomLeft: const Radius.circular(3),
                      topRight: downloadPercentage > 0.99 ? const Radius.circular(3) : Radius.zero,
                      bottomRight: downloadPercentage > 0.99 ? const Radius.circular(3) : Radius.zero,
                    ),
                  ),
                ),
              ),
              // Upload bar
              Expanded(
                flex: ((1 - downloadPercentage) * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: _theme.primaryColor,
                    borderRadius: BorderRadius.only(
                      topRight: const Radius.circular(3),
                      bottomRight: const Radius.circular(3),
                      topLeft: downloadPercentage < 0.01 ? const Radius.circular(3) : Radius.zero,
                      bottomLeft: downloadPercentage < 0.01 ? const Radius.circular(3) : Radius.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  /// Build usage statistics row
  Widget _buildUsageStats(User user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Download details
        _buildStatItem(
          icon: Icons.download,
          label: "Download",
          value: user.formattedDownload,
          color: _theme.secondaryColor,
        ),
        // Upload details
        _buildStatItem(
          icon: Icons.upload,
          label: "Upload",
          value: user.formattedUpload,
          color: _theme.primaryColor,
        ),
        // Connection time
        _buildStatItem(
          icon: Icons.timer,
          label: "Uptime",
          value: user.formattedUptime,
          color: _theme.accentColor,
        ),
      ],
    );
  }

  /// Build stat item (download/upload/time)
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: _theme.textSecondaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  /// Format bytes to human readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return "$bytes B";
    } else if (bytes < (1024 * 1024)) {
      double kb = bytes / 1024;
      return "${kb.toStringAsFixed(1)} KB";
    } else if (bytes < (1024 * 1024 * 1024)) {
      double mb = bytes / (1024 * 1024);
      return "${mb.toStringAsFixed(1)} MB";
    } else {
      double gb = bytes / (1024 * 1024 * 1024);
      return "${gb.toStringAsFixed(1)} GB";
    }
  }
}

/// App theme class to centralize color definitions
class AppTheme {
  // App colors
  final Color primaryColor = const Color(0xFF3B82F6);
  final Color secondaryColor = const Color(0xFF10B981);
  final Color accentColor = const Color(0xFFF59E0B);
  final Color backgroundColor = const Color(0xFFF9FAFB);
  final Color cardColor = Colors.white;
  final Color textPrimaryColor = const Color(0xFF1F2937);
  final Color textSecondaryColor = const Color(0xFF6B7280);
  final Color errorColor = const Color(0xFFEF4444);
}