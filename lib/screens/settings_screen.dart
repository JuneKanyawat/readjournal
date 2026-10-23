import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_data.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ─── User Profile ──────────────────────────────────────────────
  final String _userName = 'June Reader';
  final String _email = 'june@readjournal.app';

  // ─── Rating Topics ─────────────────────────────────────────────
  List<String> _ratingTopics = [];
  final TextEditingController _newTopicController = TextEditingController();
  int? _editingTopicIndex;
  final TextEditingController _editTopicController = TextEditingController();

  // ─── Genre Tags ────────────────────────────────────────────────
  final List<String> _genreTags = [
    'Fantasy',
    'Romance',
    'Thriller',
    'Sci-Fi',
    'Dark Fantasy',
    'Slow Burn',
    'Mystery',
  ];
  final TextEditingController _newGenreController = TextEditingController();

  // ─── Publishers ────────────────────────────────────────────────
  List<String> _publishers = [];
  final TextEditingController _newPublisherController = TextEditingController();

  // ─── Firestore Settings Subscription ───────────────────────────
  StreamSubscription? _settingsSubscription;

  // ─── App Preferences ──────────────────────────────────────────
  int _selectedThemeIndex = 0;
  final List<Map<String, dynamic>> _themes = [
    {'name': 'Cozy Amber', 'color': AppColors.primary, 'icon': Icons.wb_sunny_outlined},
    {'name': 'Midnight Dark', 'color': const Color(0xFF1A1A2E), 'icon': Icons.dark_mode_outlined},
    {'name': 'Pastel Light', 'color': const Color(0xFFB8C6DB), 'icon': Icons.light_mode_outlined},
  ];
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _ratingTopics = List.from(AppData.ratingTopics);
    _publishers = List.from(AppData.publishers);

    // Subscribe to Firestore preferences
    _settingsSubscription = FirestoreService.getSettingsStream()?.listen((doc) {
      if (!doc.exists) return;
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          if (data['ratingTopics'] is List) {
            _ratingTopics = (data['ratingTopics'] as List).map((e) => e.toString()).toList();
          }
          if (data['publishers'] is List) {
            _publishers = (data['publishers'] as List).map((e) => e.toString()).toList();
          }
        });
        FirestoreService.syncToAppData(data);
      }
    });
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _newTopicController.dispose();
    _editTopicController.dispose();
    _newGenreController.dispose();
    _newPublisherController.dispose();
    super.dispose();
  }

  // ─── Rating Topic Actions ─────────────────────────────────────
  void _addRatingTopic() {
    final text = _newTopicController.text.trim();
    if (text.isNotEmpty && !_ratingTopics.contains(text)) {
      setState(() {
        _ratingTopics.add(text);
        _newTopicController.clear();
      });
      FirestoreService.addRatingTopic(text);
    }
  }

  void _deleteRatingTopic(int index) {
    final topic = _ratingTopics[index];
    setState(() {
      _ratingTopics.removeAt(index);
      if (_editingTopicIndex == index) _editingTopicIndex = null;
    });
    FirestoreService.removeRatingTopic(topic);
  }

  void _startEditTopic(int index) {
    setState(() {
      _editingTopicIndex = index;
      _editTopicController.text = _ratingTopics[index];
    });
  }

  void _saveEditTopic(int index) {
    final text = _editTopicController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _ratingTopics[index] = text;
        _editingTopicIndex = null;
      });
      FirestoreService.updateRatingTopics(_ratingTopics);
    }
  }

  // ─── Genre Tag Actions ────────────────────────────────────────
  void _addGenreTag() {
    final text = _newGenreController.text.trim();
    if (text.isNotEmpty && !_genreTags.contains(text)) {
      setState(() {
        _genreTags.add(text);
        _newGenreController.clear();
      });
    }
  }

  void _removeGenreTag(String tag) {
    setState(() {
      _genreTags.remove(tag);
    });
  }

  // ─── Publisher Actions ────────────────────────────────────────
  void _addPublisher() {
    final text = _newPublisherController.text.trim();
    if (text.isNotEmpty && !_publishers.contains(text)) {
      setState(() {
        _publishers.add(text);
        _newPublisherController.clear();
      });
      FirestoreService.addPublisher(text);
    }
  }

  void _removePublisher(String publisher) {
    setState(() {
      _publishers.remove(publisher);
    });
    FirestoreService.removePublisher(publisher);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    _buildProfileCard(),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Rating Criteria',
                      subtitle: 'Customize your 5-star rating dimensions',
                      icon: Icons.star_rounded,
                      child: _buildRatingTopicsSection(),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Genre Tags',
                      subtitle: 'Manage your book genre categories',
                      icon: Icons.local_offer_rounded,
                      child: _buildGenreTagsSection(),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Publishers',
                      subtitle: 'Manage your book publishers',
                      icon: Icons.business_rounded,
                      child: _buildPublishersSection(),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Appearance',
                      subtitle: 'Customize how your app looks',
                      icon: Icons.palette_rounded,
                      child: _buildAppPreferencesSection(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PROFILE CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildProfileCard() {
    final user = AuthService.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.isAnonymous == true ? 'Guest Reader' : _userName);
    final displayEmail = user?.email?.isNotEmpty == true
        ? user!.email!
        : (user?.isAnonymous == true ? 'Guest Session' : _email);
    final avatarLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'J';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Text(
                      avatarLetter,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayEmail,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: _buildProfileButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profile',
                    onTap: () {},
                    filled: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildProfileButton(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.cardBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                          content: const Text('Are you sure you want to sign out of ReadJournal?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await AuthService.signOut();
                      }
                    },
                    filled: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: filled ? AppColors.primary : Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: filled ? AppColors.primary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECTION CARD WRAPPER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RATING TOPICS SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRatingTopicsSection() {
    return Column(
      children: [
        // Existing topics list
        ...List.generate(_ratingTopics.length, (index) {
          final isEditing = _editingTopicIndex == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isEditing
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEditing ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                // Star icon
                Icon(Icons.star_rounded, size: 18, color: AppColors.starActive),
                const SizedBox(width: 10),
                // Name or edit field
                Expanded(
                  child: isEditing
                      ? TextField(
                          controller: _editTopicController,
                          autofocus: true,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _saveEditTopic(index),
                        )
                      : Text(
                          _ratingTopics[index],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
                // Action buttons
                if (isEditing) ...[
                  _buildIconAction(Icons.check_rounded, AppColors.accent, () => _saveEditTopic(index)),
                  const SizedBox(width: 4),
                  _buildIconAction(Icons.close_rounded, AppColors.textSecondary, () {
                    setState(() => _editingTopicIndex = null);
                  }),
                ] else ...[
                  _buildIconAction(Icons.edit_outlined, AppColors.textSecondary, () => _startEditTopic(index)),
                  const SizedBox(width: 4),
                  _buildIconAction(Icons.delete_outline_rounded, const Color(0xFFCC5B5B), () => _deleteRatingTopic(index)),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 8),

        // Add new topic input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newTopicController,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'New rating criteria...',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _addRatingTopic(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: _addRatingTopic,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconAction(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GENRE TAGS SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGenreTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tags
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _genreTags.map((tag) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeGenreTag(tag),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // Add new genre input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newGenreController,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Add new genre tag...',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _addGenreTag(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: _addGenreTag,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLISHERS SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPublishersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Publisher chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _publishers.map((publisher) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: AppColors.primaryDark.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_outlined, size: 14, color: AppColors.primaryDark),
                        const SizedBox(width: 6),
                        Text(
                          publisher,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removePublisher(publisher),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // Add new publisher input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newPublisherController,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Add new publisher...',
                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _addPublisher(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: _addPublisher,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // APP PREFERENCES SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAppPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Theme Selector
        const Text(
          'Theme',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_themes.length, (index) {
            final theme = _themes[index];
            final isSelected = _selectedThemeIndex == index;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < _themes.length - 1 ? 10 : 0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedThemeIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (theme['color'] as Color).withValues(alpha: 0.1)
                          : AppColors.secondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? (theme['color'] as Color)
                            : AppColors.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme['color'] as Color,
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: (theme['color'] as Color).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Icon(
                            theme['icon'] as IconData,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          theme['name'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? theme['color'] as Color
                                : AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 20),

        // Bookshelf View Toggle
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.view_module_rounded, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Bookshelf View',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose how books are displayed',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.divider.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildViewToggleButton(
                      icon: Icons.grid_view_rounded,
                      label: 'Grid',
                      isActive: _isGridView,
                      onTap: () => setState(() => _isGridView = true),
                    ),
                    _buildViewToggleButton(
                      icon: Icons.view_list_rounded,
                      label: 'List',
                      isActive: !_isGridView,
                      onTap: () => setState(() => _isGridView = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
