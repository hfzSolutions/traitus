import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:traitus/config/default_ai_config.dart';
import 'package:traitus/providers/auth_provider.dart';
import 'package:traitus/services/storage_service.dart';
import 'package:traitus/services/openrouter_api.dart';
import 'package:traitus/ui/home_page.dart';
import 'package:traitus/providers/chats_list_provider.dart';
import 'package:traitus/ui/widgets/app_avatar.dart';
import 'package:traitus/ui/widgets/haptic_modal.dart';
import 'package:traitus/services/notification_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _customInterestsController = TextEditingController();
  final Set<String> _selectedPreferences = {};
  final Set<String> _selectedAIChats = {};
  final List<String> _customInterests = [];
  bool _isLoading = false;
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Loading carousel state
  Timer? _loadingCarouselTimer;
  int _loadingCarouselIndex = 0;
  final List<String> _loadingCarouselMessages = const [
    'This may take a moment.',
    'Setting up your assistants...',
  ];
  
  // New fields
  File? _selectedImage;
  DateTime? _selectedDateOfBirth;
  String _selectedLanguage = 'en';
  String? _experienceLevel; // 'beginner', 'intermediate', 'advanced'
  String? _useContext; // 'work', 'personal', 'both'
  final _imagePicker = ImagePicker();
  final _storageService = StorageService();
  final _openRouterApi = OpenRouterApi();

  // AI recommendation state
  List<String>? _aiRecommendedChatIds;
  List<Map<String, dynamic>>? _aiDynamicChats;
  bool _isRecommending = false;
  String? _recommendError;

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
    {
      'id': 'others',
      'title': 'Others',
      'subtitle': 'Custom Interests',
      'description': 'Add your own interests',
      'icon': Icons.add_circle_outline,
      'color': const Color(0xFF757575),
    },
  ];

  // Available languages
  final List<Map<String, String>> _availableLanguages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'id', 'name': 'Indonesian', 'flag': '🇮🇩'},
    {'code': 'ms', 'name': 'Malay', 'flag': '🇲🇾'},
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
    _customInterestsController.dispose();
    _animationController.dispose();
    _loadingCarouselTimer?.cancel();
    super.dispose();
  }

  void _changeStep(int newStep) {
    setState(() {
      _currentStep = newStep;
      _animationController.reset();
      _animationController.forward();
    });

    // When entering AI selection step, fetch AI-based recommendations
    if (newStep == 4) {
      _fetchAiRecommendations();
    }
  }

  void _addCustomInterest(String interest) {
    final trimmed = interest.trim();
    if (trimmed.isNotEmpty && !_customInterests.contains(trimmed)) {
      setState(() {
        _customInterests.add(trimmed);
        _customInterestsController.clear();
      });
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        if (!mounted) return;
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') || errorString.contains('denied')) {
        // Show appropriate dialog based on source
        if (source == ImageSource.camera) {
          await NotificationService.showEnableCameraDialog(context);
        } else {
          await NotificationService.showEnablePhotoLibraryDialog(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourcePicker() async {
    final theme = Theme.of(context);
    await HapticModal.showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_rounded, color: theme.colorScheme.primary),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: theme.colorScheme.primary),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExperienceChip(String value, String label, IconData icon) {
    final isSelected = _experienceLevel == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _experienceLevel = selected ? value : null;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildUseContextChip(String value, String label, IconData icon) {
    final isSelected = _useContext == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _useContext = selected ? value : null;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
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
      if (!mounted) return;
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _fetchAiRecommendations() async {
    // Combine selected preferences (excluding 'others') with custom interests
    final preferencesForRecommendation = <String>[
      ..._selectedPreferences.where((p) => p != 'others'),
      ..._customInterests,
    ];
    
    if (preferencesForRecommendation.isEmpty) {
      setState(() {
        _aiRecommendedChatIds = null;
        _aiDynamicChats = null;
        _recommendError = null;
        _isRecommending = false;
      });
      _loadingCarouselTimer?.cancel();
      return;
    }

    setState(() {
      _isRecommending = true;
      _recommendError = null;
    });
    // Start carousel
    _loadingCarouselTimer?.cancel();
    _loadingCarouselIndex = 0;
    _loadingCarouselTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted || !_isRecommending) {
        t.cancel();
        return;
      }
      setState(() {
        _loadingCarouselIndex = (_loadingCarouselIndex + 1) % _loadingCarouselMessages.length;
      });
    });

    List<Map<String, dynamic>>? dynamicChats;
    bool dynamicChatsSucceeded = false;
    
    // Try dynamic assistant definitions first
    try {
      dynamicChats = await _openRouterApi.recommendChatDefinitions(
        selectedPreferences: preferencesForRecommendation,
        languageCode: _selectedLanguage,
        displayName: _usernameController.text.trim().isNotEmpty
            ? _usernameController.text.trim()
            : null,
        dateOfBirth: _selectedDateOfBirth,
        experienceLevel: _experienceLevel,
        useContext: _useContext,
      );
      dynamicChatsSucceeded = true;
      if (mounted) {
        setState(() {
          _aiDynamicChats = dynamicChats!.isNotEmpty ? dynamicChats : null;
        });
      }
    } catch (e) {
      // Dynamic chats failed, will try fallback
      dynamicChatsSucceeded = false;
      if (mounted) {
        setState(() {
          _aiDynamicChats = null;
        });
      }
    }

    // Only compute fallback ordered IDs if dynamic chats failed or returned empty
    if (!dynamicChatsSucceeded || (dynamicChats != null && dynamicChats.isEmpty)) {
      try {
        final allowedIds = _availableAIChats.keys.toList();
        final ids = await _openRouterApi.recommendChatIds(
          selectedPreferences: preferencesForRecommendation,
          allowedChatIds: allowedIds,
        );
        if (!mounted) return;
        setState(() {
          _aiRecommendedChatIds = ids;
          _recommendError = null; // Clear error if fallback succeeds
        });
      } catch (e) {
        // Fallback also failed
        if (mounted) {
          setState(() {
            _recommendError = e.toString();
            _aiRecommendedChatIds = null;
          });
        }
      }
    } else {
      // Clear fallback IDs since we have dynamic chats
      if (mounted) {
        setState(() {
          _aiRecommendedChatIds = null;
          _recommendError = null; // Clear any previous errors
        });
      }
    }
    
    // Final cleanup
    if (mounted) {
      setState(() {
        _isRecommending = false;
      });
      HapticFeedback.selectionClick();
      _loadingCarouselTimer?.cancel();
    }
  }

  List<Map<String, dynamic>> _getRecommendedChats() {
    // Combine selected preferences (excluding 'others') with custom interests
    final preferencesForFiltering = <String>[
      ..._selectedPreferences.where((p) => p != 'others'),
      ..._customInterests,
    ];
    
    // Prefer dynamic suggestions if present
    if (_aiDynamicChats != null && _aiDynamicChats!.isNotEmpty) {
      return _aiDynamicChats!;
    }
    // If AI provided ordering, use it and filter to preferences match
    if (_aiRecommendedChatIds != null && _aiRecommendedChatIds!.isNotEmpty) {
      final byId = _availableAIChats;
      final filteredOrdered = _aiRecommendedChatIds!
          .map((id) => byId[id])
          .where((chat) => chat != null)
          .cast<Map<String, dynamic>>()
          .where((chat) => preferencesForFiltering.contains(chat['preference']))
          .toList();
      if (filteredOrdered.isNotEmpty) return filteredOrdered;
    }
    // Fallback: simple filter by selected preferences
    return _availableAIChats.values
        .where((chat) => preferencesForFiltering.contains(chat['preference']))
        .toList();
  }

  Future<void> _skipOnboarding() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Personalization?'),
        content: const Text(
          'You can always personalize your experience later in settings. Are you sure you want to skip?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? avatarUrl;
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Upload/update profile image if selected (delete old to avoid duplicates)
      if (_selectedImage != null) {
        avatarUrl = await _storageService.updateUserAvatar(
          _selectedImage!.path,
          authProvider.userProfile?.avatarUrl,
        );
      }

      // Complete onboarding with only profile data (no interests, experience, context, or AI chats)
      await authProvider.completeOnboarding(
        displayName: _usernameController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        preferredLanguage: _selectedLanguage,
        avatarUrl: avatarUrl,
        experienceLevel: null, // Skip experience
        useContext: null, // Skip context
        preferences: [], // No interests
        selectedChatIds: [], // No AI chats
        selectedChatDefinitions: [], // No AI chat definitions
      );

      if (!mounted) return;

      // Refresh chats so Home shows the latest list
      try {
        await context.read<ChatsListProvider>().refreshChats();
      } catch (_) {}

      // Navigate directly to chat screen
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
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

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? avatarUrl;
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Upload/update profile image if selected (delete old to avoid duplicates)
      if (_selectedImage != null) {
        avatarUrl = await _storageService.updateUserAvatar(
          _selectedImage!.path,
          authProvider.userProfile?.avatarUrl,
        );
      }

      // Build selected definitions from currently recommended list
      final recommended = _getRecommendedChats();
      final selectedDefs = recommended
          .where((c) => _selectedAIChats.contains((c['id'] as String)))
          .toList();

      // Combine selected preferences with custom interests
      final allPreferences = <String>[
        ..._selectedPreferences.where((p) => p != 'others'),
        ..._customInterests,
      ];

      // Log what user is submitting
      debugPrint('[Onboarding] Submitting: ${_selectedAIChats.length} AI chats, ${selectedDefs.length} definitions');

      // Complete onboarding with all user data
      await authProvider.completeOnboarding(
        displayName: _usernameController.text.trim(),
        dateOfBirth: _selectedDateOfBirth,
        preferredLanguage: _selectedLanguage,
        avatarUrl: avatarUrl,
        experienceLevel: _experienceLevel,
        useContext: _useContext,
        preferences: allPreferences,
        selectedChatIds: _selectedAIChats.toList(),
        selectedChatDefinitions: selectedDefs,
      );

      if (!mounted) return;

      // Success toast removed per request

      // Refresh chats so Home shows the latest list created during onboarding
      try {
        await context.read<ChatsListProvider>().refreshChats();
      } catch (_) {}

      // Ensure we leave onboarding after success
      // Give the snackbar a tick to show, then navigate to Home
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
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
            // Traitus logo
            Image.asset(
              'assets/logo.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            
            // Welcome text
            Text(
              'Welcome',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Let\'s get you started',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                'Set up your basic profile details',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Profile Image Selector
              Center(
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final displayName = _usernameController.text.trim().isNotEmpty
                        ? _usernameController.text.trim()
                        : (auth.userProfile?.displayName ?? 'User');
                    final imageUrl = auth.userProfile?.avatarUrl;
                    return GestureDetector(
                      onTap: () { _showImageSourcePicker(); },
                      child: Stack(
                        children: [
                          // Base avatar (existing profile or initials)
                          ClipOval(
                            child: SizedBox(
                              width: 120,
                              height: 120,
                              child: AppAvatar(
                                size: 120,
                                name: displayName,
                                imageUrl: _selectedImage == null ? imageUrl : null,
                                isCircle: true,
                              ),
                            ),
                          ),
                          // If a new image is picked, preview it on top
                          if (_selectedImage != null)
                            ClipOval(
                              child: Image.file(
                                _selectedImage!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
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
                    );
                  },
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
              
              // Date of Birth field (required)
              FormField<DateTime?>(
                validator: (_) {
                  if (_selectedDateOfBirth == null) {
                    return 'Please select your date of birth';
                  }
                  return null;
                },
                builder: (state) {
                  return InkWell(
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
                        errorText: state.errorText,
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
                  );
                },
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
                      HapticFeedback.selectionClick();
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
                                  // Clear custom interests if "Others" is deselected
                                  if (pref['id'] == 'others') {
                                    _customInterests.clear();
                                    _customInterestsController.clear();
                                  }
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
                      
                      // Custom interests input (shown when "Others" is selected)
                      if (_selectedPreferences.contains('others')) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customInterestsController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Astronomy',
                                  prefixIcon: const Icon(Icons.edit_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surface,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (value) {
                                  _addCustomInterest(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                _addCustomInterest(_customInterestsController.text);
                              },
                              icon: const Icon(Icons.add_circle_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                        if (_customInterests.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _customInterests.map((interest) {
                              return Chip(
                                label: Text(interest),
                                onDeleted: () {
                                  setState(() {
                                    _customInterests.remove(interest);
                                  });
                                },
                                deleteIcon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                      
                      if (_selectedPreferences.isNotEmpty || _customInterests.isNotEmpty) ...[
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
                                '${(_selectedPreferences.where((p) => p != 'others').length + _customInterests.length)} ${(_selectedPreferences.where((p) => p != 'others').length + _customInterests.length) == 1 ? "interest" : "interests"} selected',
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                        onPressed: (_selectedPreferences.where((p) => p != 'others').isEmpty && _customInterests.isEmpty)
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                _changeStep(3);
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
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _skipOnboarding();
                  },
                  child: Text(
                    'Skip personalization',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          decoration: TextDecoration.underline,
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

  Widget _buildExperienceAndContextStep() {
    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Experience Level Section
                Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Experience Level',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildExperienceChip('beginner', 'Beginner', Icons.rocket_launch_rounded),
                          _buildExperienceChip('intermediate', 'Intermediate', Icons.trending_up_rounded),
                          _buildExperienceChip('advanced', 'Advanced', Icons.star_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Use Context Section
                Row(
                  children: [
                    Icon(
                      Icons.work_outline_rounded,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Primary Use',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildUseContextChip('work', 'Work', Icons.business_center_rounded),
                          _buildUseContextChip('personal', 'Personal', Icons.person_outline_rounded),
                          _buildUseContextChip('both', 'Both', Icons.balance_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Subtle reference to selected preferences
                if (_selectedPreferences.where((p) => p != 'others').isNotEmpty || _customInterests.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Based on your ${_selectedPreferences.where((p) => p != 'others').length + _customInterests.length} ${(_selectedPreferences.where((p) => p != 'others').length + _customInterests.length) == 1 ? 'interest' : 'interests'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                            textAlign: TextAlign.center,
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
                    onPressed: () => _changeStep(2),
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
                    onPressed: (_experienceLevel == null || _useContext == null)
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            _changeStep(4);
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

  Widget _buildAIChatSelectionStep() {
    final recommendedChats = _getRecommendedChats();
    
    // Clean up selected chats - remove any that are no longer in recommendations
    final recommendedChatIds = recommendedChats.map((chat) => chat['id'] as String).toSet();
    _selectedAIChats.removeWhere((chatId) => !recommendedChatIds.contains(chatId));

    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: _isRecommending
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Finding the best assistants for you...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeIn,
                          switchOutCurve: Curves.easeOut,
                          child: Text(
                            _loadingCarouselMessages[_loadingCarouselIndex],
                            key: ValueKey(_loadingCarouselIndex),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : recommendedChats.isEmpty
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
                        _recommendError != null
                            ? 'Could not get AI recommendations'
                            : 'No recommendations available',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _recommendError != null
                            ? 'You can add assistants later.'
                            : 'Update interests to see suggestions.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
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
                              'Based on your interests, we recommend these AI assistants. Select the ones you\'d like.',
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
                                // Avatar (use initial-based gradient, ignore emoji/url)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AppAvatar(
                                    size: 64,
                                    name: chat['name'] as String,
                                    imageUrl: null,
                                    isCircle: false,
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
                                        (chat['shortDescription'] as String?) ?? (chat['description'] as String? ?? ''),
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
                    // Regenerate button
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                        child: Align(
                          alignment: Alignment.center,
                          child: TextButton.icon(
                            onPressed: _isRecommending
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    _fetchAiRecommendations();
                                  },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Regenerate suggestions'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
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
                    onPressed: _isLoading ? null : () => _changeStep(3),
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
                    onPressed: (_isLoading || _isRecommending || (_selectedAIChats.isEmpty && recommendedChats.isNotEmpty))
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _completeOnboarding();
                          },
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
                    label: Text(
                      _isLoading
                          ? 'Setting up...'
                          : _isRecommending
                              ? 'Finding...'
                              : (_selectedAIChats.isEmpty && recommendedChats.isNotEmpty)
                                  ? 'Select at least one'
                                  : (_selectedAIChats.isEmpty && recommendedChats.isEmpty)
                                      ? 'Complete'
                                      : 'Complete (${_selectedAIChats.length})',
                    ),
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
      resizeToAvoidBottomInset: false,
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
                              'Step $_currentStep of 4',
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
                                value: _currentStep / 4,
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
                      _buildExperienceAndContextStep(),
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
