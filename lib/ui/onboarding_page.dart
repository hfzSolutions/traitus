import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:traitus/config/default_ai_config.dart';
import 'package:traitus/providers/auth_provider.dart';
import 'package:traitus/services/storage_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final Set<String> _selectedPreferences = {};
  final Set<String> _selectedAIChats = {};
  bool _isLoading = false;
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // New fields
  File? _selectedImage;
  DateTime? _selectedDateOfBirth;
  String _selectedLanguage = 'en';
  final _imagePicker = ImagePicker();
  final _storageService = StorageService();

  // Available preferences for AI chat selection
  final List<Map<String, dynamic>> _availablePreferences = [
    {
      'id': 'coding',
      'title': 'Coding',
      'subtitle': 'Programming & Development',
      'description': 'Help with programming and software development',
      'icon': Icons.code,
      'color': Colors.blue,
    },
    {
      'id': 'creative',
      'title': 'Creative',
      'subtitle': 'Writing & Storytelling',
      'description': 'Assistance with creative writing and storytelling',
      'icon': Icons.create,
      'color': Colors.purple,
    },
    {
      'id': 'research',
      'title': 'Research',
      'subtitle': 'Information & Analysis',
      'description': 'Help with research and information gathering',
      'icon': Icons.search,
      'color': Colors.orange,
    },
    {
      'id': 'productivity',
      'title': 'Productivity',
      'subtitle': 'Time & Task Management',
      'description': 'Tips for time management and productivity',
      'icon': Icons.trending_up,
      'color': Colors.green,
    },
    {
      'id': 'learning',
      'title': 'Learning',
      'subtitle': 'Education & Tutoring',
      'description': 'Educational support and explanations',
      'icon': Icons.school,
      'color': Colors.teal,
    },
    {
      'id': 'business',
      'title': 'Business',
      'subtitle': 'Strategy & Analysis',
      'description': 'Business strategy and analysis',
      'icon': Icons.business_center,
      'color': Colors.indigo,
    },
    {
      'id': 'marketing',
      'title': 'Marketing',
      'subtitle': 'SEO & Content Strategy',
      'description': 'Marketing, SEO, and social media',
      'icon': Icons.campaign,
      'color': Colors.pink,
    },
    {
      'id': 'legal',
      'title': 'Legal',
      'subtitle': 'Law & Compliance',
      'description': 'Legal advice and contract review',
      'icon': Icons.gavel,
      'color': Colors.brown,
    },
    {
      'id': 'medical',
      'title': 'Medical',
      'subtitle': 'Healthcare & Wellness',
      'description': 'Health and medical information',
      'icon': Icons.medical_services,
      'color': const Color(0xFFD32F2F),
    },
    {
      'id': 'finance',
      'title': 'Finance',
      'subtitle': 'Investing & Accounting',
      'description': 'Financial planning and analysis',
      'icon': Icons.account_balance,
      'color': const Color(0xFF1976D2),
    },
    {
      'id': 'entertainment',
      'title': 'Entertainment',
      'subtitle': 'Movies, Music & Games',
      'description': 'Entertainment recommendations',
      'icon': Icons.movie,
      'color': const Color(0xFF7B1FA2),
    },
    {
      'id': 'travel',
      'title': 'Travel',
      'subtitle': 'Tourism & Adventure',
      'description': 'Travel planning and tips',
      'icon': Icons.flight,
      'color': Colors.cyan,
    },
    {
      'id': 'food',
      'title': 'Food & Cooking',
      'subtitle': 'Recipes & Nutrition',
      'description': 'Cooking and recipe suggestions',
      'icon': Icons.restaurant,
      'color': const Color(0xFFFF5722),
    },
    {
      'id': 'sports',
      'title': 'Sports & Fitness',
      'subtitle': 'Exercise & Athletics',
      'description': 'Fitness and sports guidance',
      'icon': Icons.fitness_center,
      'color': const Color(0xFF689F38),
    },
    {
      'id': 'engineering',
      'title': 'Engineering',
      'subtitle': 'Design & Construction',
      'description': 'Engineering and technical design',
      'icon': Icons.engineering,
      'color': Colors.blueGrey,
    },
    {
      'id': 'real_estate',
      'title': 'Real Estate',
      'subtitle': 'Property & Investment',
      'description': 'Real estate advice',
      'icon': Icons.home_work,
      'color': Colors.amber,
    },
    {
      'id': 'environment',
      'title': 'Environment',
      'subtitle': 'Sustainability & Nature',
      'description': 'Environmental topics',
      'icon': Icons.eco,
      'color': const Color(0xFF558B2F),
    },
    {
      'id': 'psychology',
      'title': 'Psychology',
      'subtitle': 'Mental Health & Behavior',
      'description': 'Psychology and mental wellness',
      'icon': Icons.psychology,
      'color': const Color(0xFF9C27B0),
    },
    {
      'id': 'languages',
      'title': 'Languages',
      'subtitle': 'Learning & Translation',
      'description': 'Language learning support',
      'icon': Icons.translate,
      'color': const Color(0xFF0288D1),
    },
    {
      'id': 'fashion',
      'title': 'Fashion',
      'subtitle': 'Style & Trends',
      'description': 'Fashion advice and trends',
      'icon': Icons.checkroom,
      'color': const Color(0xFFEC407A),
    },
    {
      'id': 'photography',
      'title': 'Photography',
      'subtitle': 'Visual Arts',
      'description': 'Photography tips and techniques',
      'icon': Icons.camera_alt,
      'color': const Color(0xFF616161),
    },
    {
      'id': 'music',
      'title': 'Music',
      'subtitle': 'Composition & Production',
      'description': 'Music creation and theory',
      'icon': Icons.music_note,
      'color': const Color(0xFF8E24AA),
    },
    {
      'id': 'gaming',
      'title': 'Gaming',
      'subtitle': 'Video Games & Esports',
      'description': 'Gaming strategies and news',
      'icon': Icons.sports_esports,
      'color': const Color(0xFF6A1B9A),
    },
    {
      'id': 'automotive',
      'title': 'Automotive',
      'subtitle': 'Cars & Mechanics',
      'description': 'Car maintenance and advice',
      'icon': Icons.directions_car,
      'color': const Color(0xFFC62828),
    },
    {
      'id': 'science',
      'title': 'Science',
      'subtitle': 'Research & Discovery',
      'description': 'Scientific knowledge and research',
      'icon': Icons.science,
      'color': const Color(0xFF00897B),
    },
  ];

  // Available languages
  final List<Map<String, String>> _availableLanguages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'id', 'name': 'Indonesian', 'flag': '🇮🇩'},
    {'code': 'es', 'name': 'Spanish', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'de', 'name': 'German', 'flag': '🇩🇪'},
    {'code': 'ja', 'name': 'Japanese', 'flag': '🇯🇵'},
    {'code': 'ko', 'name': 'Korean', 'flag': '🇰🇷'},
    {'code': 'zh', 'name': 'Chinese', 'flag': '🇨🇳'},
    {'code': 'ar', 'name': 'Arabic', 'flag': '🇸🇦'},
    {'code': 'hi', 'name': 'Hindi', 'flag': '🇮🇳'},
  ];

  // Get available AI chats from config (loaded from env)
  Map<String, Map<String, dynamic>> get _availableAIChats =>
      DefaultAIConfig.getAvailableAIChats();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _changeStep(int newStep) {
    setState(() {
      _currentStep = newStep;
      _animationController.reset();
      _animationController.forward();
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Your Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  List<Map<String, dynamic>> _getRecommendedChats() {
    return _availableAIChats.values
        .where((chat) => _selectedPreferences.contains(chat['preference']))
        .toList();
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? avatarUrl;
      
      // Upload profile image if selected
      if (_selectedImage != null) {
        avatarUrl = await _storageService.uploadUserAvatar(_selectedImage!.path);
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Complete onboarding with all user data
      await authProvider.completeOnboarding(
        displayName: _usernameController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        preferredLanguage: _selectedLanguage,
        avatarUrl: avatarUrl,
        preferences: _selectedPreferences.toList(),
        selectedChatIds: _selectedAIChats.toList(),
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedAIChats.isEmpty
                      ? 'Welcome! You can create AI chats anytime.'
                      : 'Welcome! Your AI assistants are ready.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildWelcomeStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon with gradient background
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_rounded,
                size: 70,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            
            // Welcome text
            Text(
              'Welcome to Traitus',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            Text(
              'Your Personal AI Assistant Hub',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            Text(
              'Let\'s set up your personalized experience with AI assistants tailored to your needs',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            // Get started button
            FilledButton.icon(
              onPressed: () => _changeStep(1),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Get Started'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStep() {
    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Title
              Text(
                'Tell Us About Yourself',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              Text(
                'Help us personalize your experience',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Profile Image Selector
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? Icon(
                                Icons.person_rounded,
                                size: 60,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to add profile photo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Username field
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  prefixIcon: const Icon(Icons.badge_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  if (value.trim().length < 2) {
                    return 'Username must be at least 2 characters';
                  }
                  if (value.trim().length > 30) {
                    return 'Username must be less than 30 characters';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              
              // Date of Birth field
              InkWell(
                onTap: _selectDateOfBirth,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'Select your date of birth',
                    prefixIcon: const Icon(Icons.cake_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    _selectedDateOfBirth != null
                        ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                        : 'Tap to select',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedDateOfBirth != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Language Selection
              DropdownButtonFormField<String>(
                initialValue: _selectedLanguage,
                decoration: InputDecoration(
                  labelText: 'Language',
                  hintText: 'Select your preferred language',
                  prefixIcon: const Icon(Icons.language_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                items: _availableLanguages.map((lang) {
                  return DropdownMenuItem<String>(
                    value: lang['code'],
                    child: Text(
                      lang['name']!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLanguage = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        
        // Fixed bottom navigation
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _changeStep(0),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _changeStep(2);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesStep() {
    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  'Choose Your Interests',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                Text(
                  'Select topics you\'re interested in to get personalized AI assistant recommendations',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Interests Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chip-based selection (cleaner approach)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _availablePreferences.map((pref) {
                          final isSelected = _selectedPreferences.contains(pref['id']);
                          return FilterChip(
                            selected: isSelected,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  pref['icon'] as IconData,
                                  size: 18,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : pref['color'] as Color,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  pref['title'] as String,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedPreferences.add(pref['id']);
                                } else {
                                  _selectedPreferences.remove(pref['id']);
                                }
                              });
                            },
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            selectedColor: Theme.of(context).colorScheme.primaryContainer,
                            checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            labelPadding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      if (_selectedPreferences.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedPreferences.length} ${_selectedPreferences.length == 1 ? "interest" : "interests"} selected',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        
        // Fixed bottom navigation
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _changeStep(1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _selectedPreferences.isEmpty
                        ? null
                        : () => _changeStep(3),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIChatSelectionStep() {
    final recommendedChats = _getRecommendedChats();
    
    // Clean up selected chats - remove any that are no longer in recommendations
    final recommendedChatIds = recommendedChats.map((chat) => chat['id'] as String).toSet();
    _selectedAIChats.removeWhere((chatId) => !recommendedChatIds.contains(chatId));

    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: recommendedChats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recommendations available',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please go back and select your interests',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                        child: Column(
                          children: [
                            Text(
                              'Choose Your AI Assistants',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            
                            Text(
                              'Based on your interests, we recommend these AI assistants. Select the ones you\'d like (optional).',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // List
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final chat = recommendedChats[index];
                            final isSelected = _selectedAIChats.contains(chat['id']);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedAIChats.remove(chat['id']);
                              } else {
                                _selectedAIChats.add(chat['id']);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: [
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              Theme.of(context)
                                                  .colorScheme
                                                  .tertiary,
                                            ],
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : Theme.of(context)
                                            .colorScheme
                                            .surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      chat['avatar'] as String,
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Chat info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        chat['name'] as String,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                  : null,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        chat['description'] as String,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.2)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainer,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          chat['model'] as String,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: isSelected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                fontFamily: 'monospace',
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Checkbox
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .outline,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                          },
                          childCount: recommendedChats.length,
                        ),
                      ),
                    ),
                    
                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 32),
                    ),
                  ],
                ),
        ),
        
        // Fixed bottom navigation
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _changeStep(2),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _completeOnboarding,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_isLoading
                        ? 'Setting up...'
                        : _selectedAIChats.isEmpty
                            ? 'Complete'
                            : 'Complete (${_selectedAIChats.length})'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            if (_currentStep > 0)
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _currentStep > 0 && !_isLoading
                              ? () => _changeStep(_currentStep - 1)
                              : null,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Step $_currentStep of 3',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: _currentStep / 3,
                                  minHeight: 6,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                  ],
                ),
              ),
            
            // Content with animation
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: IndexedStack(
                    index: _currentStep,
                    children: [
                      _buildWelcomeStep(),
                      _buildProfileStep(),
                      _buildPreferencesStep(),
                      _buildAIChatSelectionStep(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
