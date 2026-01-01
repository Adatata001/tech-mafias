import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth.dart';
import '../models/users.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String? _selectedRole;

  final List<Map<String, dynamic>> roles = [
    {'value': 'backend-dev', 'label': 'Backend Developer', 'iconName': 'code'},
    {'value': 'frontend-dev', 'label': 'Frontend Developer', 'iconName': 'web'},
    {'value': 'product-designer', 'label': 'Product Designer', 'iconName': 'design_services'},
    {'value': 'social-media', 'label': 'Social Media Manager', 'iconName': 'thumb_up'},
    {'value': 'graphic-designer', 'label': 'Graphic Designer', 'iconName': 'palette'},
    {'value': 'creative-director', 'label': 'Creative Director', 'iconName': 'star'},
    {'value': 'project-manager', 'label': 'Project Manager', 'iconName': 'manage_accounts'},
  ];

  IconData getIconFromString(String iconName) {
    switch (iconName) {
      case 'code':
        return Icons.code;
      case 'web':
        return Icons.web;
      case 'design_services':
        return Icons.design_services;
      case 'thumb_up':
        return Icons.thumb_up;
      case 'palette':
        return Icons.palette;
      case 'star':
        return Icons.star;
      case 'manage_accounts':
        return Icons.manage_accounts;
      default:
        return Icons.person;
    }
  }

  Future<void> _submitForm() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && _selectedRole == null) {
      setState(() => _errorMessage = 'Please select your role');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (_isLogin) {
        await auth.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        // Create default User object for new registration
        final newUser = User(
          id: '', // Firestore will generate ID
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          role: _selectedRole!,
          points: 0,
          streak: 0,
          techMafiaWins: 0,
          isMafiaOfTheWeek: false,
          createdAt: DateTime.now(),
        );

        await auth.registerUser(newUser, _passwordController.text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _parseErrorMessage(e.toString());
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _parseErrorMessage(String error) {
    if (error.contains('Invalid email or password')) return 'Invalid email or password.';
    if (error.contains('400')) return 'Invalid credentials.';
    if (error.contains('401')) return 'Authentication failed.';
    if (error.contains('409')) return 'User already exists.';
    if (error.contains('Network')) return 'Network error. Check your connection.';
    if (error.contains('timeout')) return 'Connection timeout.';
    if (error.contains('No address')) return 'Cannot connect to server.';
    return 'An unexpected error occurred.';
  }

  void _toggleLoginRegister() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _selectedRole = null;
      _emailController.clear();
      _passwordController.clear();
      _usernameController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo & Title
                      Column(
                        children: [
                          const Icon(Icons.groups, size: 80, color: Colors.deepPurple),
                          const SizedBox(height: 16),
                          const Text(
                            'Tech Mafia',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          Text(
                            _isLogin ? 'Sign in to continue' : 'Join the Mafia',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Error message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red[800]),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Username field (register only)
                      if (!_isLogin)
                        ...[
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter a username';
                              if (value.length < 3) return 'Username must be at least 3 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your email';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Please enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your password';
                          if (value.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm password & role (register only)
                      if (!_isLogin)
                        ...[
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (value) {
                              if (value != _passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                         DropdownButtonFormField<String>(
                          value: _selectedRole,
                          items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'Select a role',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          
                          ...roles.map<DropdownMenuItem<String>>((role) {
                            return DropdownMenuItem<String>(
                              value: role['value'] as String,
                              child: Row(
                                children: [
                                  Icon(getIconFromString(role['iconName'] as String), color: Colors.deepPurple, size: 20),
                                  const SizedBox(width: 10),
                                  Text(role['label'] as String),
                                ],
                              ),
                            );
                          }),
                        ],
                          onChanged: (value) {
                            setState(() => _selectedRole = value);
                          },
                          validator: (value) {
                            if (value == null) return 'Please select your role';
                            return null;
                          },
                        ),
                          const SizedBox(height: 16),
                        ],

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                )
                              : Text(
                                  _isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Toggle login/register
                      TextButton(
                        onPressed: _isSubmitting ? null : _toggleLoginRegister,
                        child: Text(
                          _isLogin
                              ? 'Don\'t have an account? Sign up'
                              : 'Already have an account? Sign in',
                          style: const TextStyle(color: Colors.deepPurple),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
