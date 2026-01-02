import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:techmafias/providers/daily_log.dart';
import 'package:techmafias/providers/auth.dart';
import 'package:techmafias/screens/profile.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _driveLinkController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<DailyLogProvider>().fetchDailyLogs();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _driveLinkController.dispose();
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
  try {
    final dailyLogProvider = Provider.of<DailyLogProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await Future.wait<void>([
      dailyLogProvider.fetchDailyLogs(),
      authProvider.refreshUserData(),
    ]);

    if (mounted) {
      setState(() {});
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refresh failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    // Re-throw to keep the refresh indicator in error state
    rethrow;
  }
}


  bool get _hasSubmittedToday {
    final dailyLogProvider = Provider.of<DailyLogProvider>(context, listen: false);
    if (dailyLogProvider.logs.isEmpty) return false;
    
    final today = DateTime.now();
    return dailyLogProvider.logs.any((log) =>
        log.date.year == today.year &&
        log.date.month == today.month &&
        log.date.day == today.day);
  }

  Future<void> _submitDailyLog() async {
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write what you learned today')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dailyLogProvider = context.read<DailyLogProvider>();
      await dailyLogProvider.submitDailyLog(
        note: _noteController.text.trim(),
        screenshotUrl: _driveLinkController.text.trim(),
      );

      await _refreshDashboard();

      _noteController.clear();
      _driveLinkController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily log submitted! +20 points 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isValidGoogleDriveLink(String link) {
    return link.contains('drive.google.com') || 
           link.contains('docs.google.com') ||
           link.startsWith('https://') ||
           link.contains('google.com/drive');
  }

  Widget _buildUserProfileHeader() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final dailyLogProvider = Provider.of<DailyLogProvider>(context, listen: false);
    final todayPoints = dailyLogProvider.getTodayPoints();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.deepPurple[100],
                    child: Text(
                      user.username.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            user.username,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isMafiaOfTheWeek)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.emoji_events, size: 14, color: Colors.amber[800]),
                                SizedBox(width: 4),
                                Text(
                                  'MVP',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    
                    SizedBox(height: 4),
                    
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    SizedBox(height: 12),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCompactStatItem(
                          icon: Icons.score,
                          value: '${user.points}',
                          label: 'Total',
                        ),
                        _buildCompactStatItem(
                          icon: Icons.today,
                          value: '$todayPoints',
                          label: 'Today',
                          color: Colors.green,
                        ),
                        _buildCompactStatItem(
                          icon: Icons.local_fire_department,
                          value: '${user.streak}',
                          label: 'Streak',
                          color: user.streak > 0 ? Colors.orange : Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color ?? Colors.deepPurple,
            ),
            SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyLogForm() {
    // ignore: unused_local_variable
    final dailyLogProvider = Provider.of<DailyLogProvider>(context);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Log',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.score, size: 16, color: Colors.deepPurple),
                    SizedBox(width: 4),
                    Text(
                      '+20 points',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          Text(
            'What did you accomplish today?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share your achievements...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.deepPurple),
              ),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Google Drive Link Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Google Drive Folder Link',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: 8),
                  Tooltip(
                    message: 'Required to submit your daily log',
                    child: Icon(Icons.help_outline, size: 16, color: Colors.grey[500]),
                  ),
                ],
              ),
              SizedBox(height: 8),
              
              TextField(
                controller: _driveLinkController,
                onChanged: (value) {
                  // Update the UI when text changes
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'https://drive.google.com/drive/folders/...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: _driveLinkController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _driveLinkController.clear();
                            setState(() {});
                          },
                          color: Colors.grey[500],
                        )
                      : null,
                  prefixIcon: Icon(
                    Icons.folder_shared,
                    color: Colors.blue[600],
                  ),
                ),
                keyboardType: TextInputType.url,
              ),
              
              if (_driveLinkController.text.isNotEmpty && !_isValidGoogleDriveLink(_driveLinkController.text))
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Please enter a valid Google Drive link',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              
              // Link validation status
              if (_driveLinkController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        _isValidGoogleDriveLink(_driveLinkController.text)
                            ? Icons.check_circle
                            : Icons.error,
                        size: 12,
                        color: _isValidGoogleDriveLink(_driveLinkController.text)
                            ? Colors.green
                            : Colors.red,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _isValidGoogleDriveLink(_driveLinkController.text)
                            ? 'Valid Google Drive link'
                            : 'Invalid link format',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isValidGoogleDriveLink(_driveLinkController.text)
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Submit button - enabled only when note is filled AND link is valid
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isSubmitting || 
                         _noteController.text.trim().isEmpty || 
                         _driveLinkController.text.trim().isEmpty ||
                         !_isValidGoogleDriveLink(_driveLinkController.text.trim()))
                  ? null
                  : _submitDailyLog,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Submit Daily Log',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          
          SizedBox(height: 12),
          
          // Requirements checklist
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requirements:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    _noteController.text.trim().isNotEmpty
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 12,
                    color: _noteController.text.trim().isNotEmpty
                        ? Colors.green
                        : Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Describe your achievements',
                    style: TextStyle(
                      fontSize: 11,
                      color: _noteController.text.trim().isNotEmpty
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    _driveLinkController.text.trim().isNotEmpty
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 12,
                    color: _driveLinkController.text.trim().isNotEmpty
                        ? Colors.green
                        : Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Provide Google Drive link',
                    style: TextStyle(
                      fontSize: 11,
                      color: _driveLinkController.text.trim().isNotEmpty
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    _isValidGoogleDriveLink(_driveLinkController.text.trim())
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 12,
                    color: _isValidGoogleDriveLink(_driveLinkController.text.trim())
                        ? Colors.green
                        : Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Valid Google Drive format',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isValidGoogleDriveLink(_driveLinkController.text.trim())
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          )
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(),
                ),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _buildUserProfileHeader(),
              
              SizedBox(height: 16),
              
              if (!_hasSubmittedToday)
                _buildDailyLogForm()
              else
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Daily Log Submitted',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You have already submitted your log for today.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.green[700]),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '+20 points awarded to your total score',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}