import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../constants/app_data.dart';
import '../models/book.dart';
import '../services/firestore_service.dart';

class AddBookScreen extends StatefulWidget {
  final Book? bookToEdit;
  const AddBookScreen({super.key, this.bookToEdit});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();

  // ─── Text Controllers ──────────────────────────────────────────
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

  // ─── Publisher Dropdown ────────────────────────────────────────
  String? _selectedPublisher;

  // ─── Settings Subscription ─────────────────────────────────────
  StreamSubscription? _settingsSub;

  // ─── Cover Customization ───────────────────────────────────────
  Uint8List? _coverImageBytes;
  static const List<int> _coverColors = [
    0xFF2B6777, // Deep Teal
    0xFF1A1A2E, // Midnight Navy
    0xFF8B3A3A, // Crimson
    0xFF3D2C29, // Espresso
    0xFF3A5A40, // Forest Sage
    0xFF5E454B, // Dusty Plum
    0xFFC86D51, // Terracotta
    0xFF2D3142, // Slate Blue
  ];
  late int _selectedColorValue;

  // ─── Status & Dates ────────────────────────────────────────────
  BookStatus _selectedStatus = BookStatus.finished;
  DateTime? _dateFinished = DateTime.now();

  // ─── Favorite & Blur Flags ─────────────────────────────────────
  bool _isFavorite = false;
  bool _isBlurred = false;

  // ─── Genres ────────────────────────────────────────────────────
  static const bool _enableGenres = true;
  final List<String> _selectedGenres = [];

  // ─── Ratings ───────────────────────────────────────────────────
  late final Map<String, double> _customRatings;

  // ─── Overall Rating Calculated from Topic Ratings ──────────────
  double get _overallRating {
    if (_customRatings.isEmpty) return 0.0;
    final sum = _customRatings.values.reduce((a, b) => a + b);
    final avg = sum / _customRatings.length;
    return (avg * 10).round() / 10.0;
  }

  @override
  void initState() {
    super.initState();
    final edit = widget.bookToEdit;
    if (edit != null) {
      _titleController.text = edit.title;
      _authorController.text = edit.author;
      _selectedPublisher = edit.publisher;
      _selectedColorValue = edit.coverColorValue;
      _selectedStatus = edit.status;
      _dateFinished = edit.dateFinished ?? DateTime.now();
      _coverImageBytes = edit.coverImageBytes;
      _isFavorite = edit.isFavorite;
      _isBlurred = edit.isBlurred;
      _selectedGenres.addAll(edit.genres);
      _customRatings = {
        for (final topic in AppData.ratingTopics)
          topic: edit.customRatings[topic] ?? 4.0,
      };
      // Keep any custom ratings that were on the book but not in default topics
      edit.customRatings.forEach((k, v) {
        _customRatings.putIfAbsent(k, () => v);
      });
    } else {
      _selectedColorValue = _coverColors[0];
      if (AppData.publishers.isNotEmpty) {
        _selectedPublisher = AppData.publishers.first;
      }
      _customRatings = {
        for (final topic in AppData.ratingTopics) topic: 4.0,
      };
    }

    _titleController.addListener(() => setState(() {}));

    _settingsSub = FirestoreService.getSettingsStream()?.listen((doc) {
      if (!doc.exists) return;
      final data = doc.data();
      if (data != null && mounted) {
        FirestoreService.syncToAppData(data);
        setState(() {
          if (_selectedPublisher == null && AppData.publishers.isNotEmpty) {
            _selectedPublisher = AppData.publishers.first;
          }
          if (data['ratingTopics'] is List) {
            for (final t in (data['ratingTopics'] as List)) {
              _customRatings.putIfAbsent(t.toString(), () => 4.0);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  // ─── Helper: Format Month & Year ───────────────────────────────
  String _formatMonthYear(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // ─── Pick Month & Year ─────────────────────────────────────────
  Future<void> _pickDateFinished() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFinished ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFinished = picked;
      });
    }
  }

  // ─── Add New Publisher Dialog ──────────────────────────────────
  void _showAddNewPublisherDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Add Publisher',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Bloomsbury Publishing',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: AppColors.secondary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  FirestoreService.addPublisher(text);
                  setState(() {
                    _selectedPublisher = text;
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // ─── Save Action ───────────────────────────────────────────────
  void _saveBook() {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.mediumImpact();

    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    final publisher = (_selectedPublisher != null && _selectedPublisher!.isNotEmpty)
        ? _selectedPublisher!
        : 'Independent';

    final initial = title.isNotEmpty ? title[0].toUpperCase() : 'B';

    final savedBook = widget.bookToEdit != null
        ? widget.bookToEdit!.copyWith(
            title: title,
            author: author,
            publisher: publisher,
            coverColorValue: _selectedColorValue,
            overallRating: _selectedStatus == BookStatus.finished ? _overallRating : 0.0,
            customRatings: _selectedStatus == BookStatus.finished ? Map.from(_customRatings) : {},
            genres: List.from(_selectedGenres),
            status: _selectedStatus,
            dateFinished: _selectedStatus == BookStatus.finished ? _dateFinished : null,
            coverInitial: initial,
            coverImageBytes: _coverImageBytes,
            isFavorite: _isFavorite,
            isBlurred: _isBlurred,
          )
        : Book(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            author: author,
            publisher: publisher,
            coverColorValue: _selectedColorValue,
            overallRating: _selectedStatus == BookStatus.finished ? _overallRating : 0.0,
            customRatings: _selectedStatus == BookStatus.finished ? Map.from(_customRatings) : {},
            genres: List.from(_selectedGenres),
            status: _selectedStatus,
            dateFinished: _selectedStatus == BookStatus.finished ? _dateFinished : null,
            coverInitial: initial,
            coverImageBytes: _coverImageBytes,
            isFavorite: _isFavorite,
            isBlurred: false,
          );

    Navigator.pop(context, savedBook);
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // 1. Cover Preview & Color Selection
              _buildCoverSection(),

              const SizedBox(height: 24),

              // 2. Book Information
              _buildSectionCard(
                title: 'Book Details',
                icon: Icons.auto_stories_rounded,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _titleController,
                      label: 'Book Title',
                      hint: 'e.g. The House in the Cerulean Sea',
                      icon: Icons.title_rounded,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter book title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _authorController,
                      label: 'Author',
                      hint: 'e.g. TJ Klune',
                      icon: Icons.person_outline_rounded,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter author name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildPublisherDropdown(),
                  ],
                ),
              ),

              // 2.5 Book Genres (ปิดการใช้งานชั่วคราว)
              if (_enableGenres) ...[
                const SizedBox(height: 20),
                _buildGenresSection(),
              ],

              const SizedBox(height: 20),

              // 2.6 Favorite Toggle Section
              _buildFavoriteSection(),

              const SizedBox(height: 20),

              // 3. Reading Status (Finished & Reading only)
              _buildSectionCard(
                title: 'Reading Status',
                icon: Icons.bookmark_added_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildStatusOption(
                          status: BookStatus.finished,
                          label: 'Finished',
                          icon: Icons.check_circle_rounded,
                        ),
                        const SizedBox(width: 12),
                        _buildStatusOption(
                          status: BookStatus.reading,
                          label: 'Reading',
                          icon: Icons.menu_book_rounded,
                        ),
                      ],
                    ),

                    // Date finished picker (shown only if status is finished)
                    if (_selectedStatus == BookStatus.finished) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Finished Date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDateFinished,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _dateFinished != null
                                    ? _formatMonthYear(_dateFinished!)
                                    : 'Select month & year',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.edit_calendar_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 4. Ratings (Only when finished)
              if (_selectedStatus == BookStatus.finished) ...[
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'Ratings',
                  icon: Icons.star_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overall Rating (Calculated from topic ratings)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Overall Rating',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Calculated from topic ratings',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${_overallRating.toStringAsFixed(1)} / 5.0',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildCalculatedStarRow(
                        rating: _overallRating,
                        starSize: 28,
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(color: AppColors.divider, height: 1),
                      ),

                      // Custom Topics
                      const Text(
                        'Topic Ratings',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      ..._customRatings.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              _buildInteractiveStarRow(
                                rating: entry.value,
                                onChanged: (val) {
                                  setState(() {
                                    _customRatings[entry.key] = val;
                                  });
                                },
                                starSize: 22,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // 5. Submit CTA
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GENRES SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGenresSection() {
    return _buildSectionCard(
      title: 'Book Genres (หมวดหมู่)',
      icon: Icons.category_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedGenres.isEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showGenrePickerSheet,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'กดเพื่อเลือกหมวดหมู่หนังสือ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'เลือกแนวหนังสือ เช่น Fiction, วรรณกรรม, พัฒนาตนเอง...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._selectedGenres.map((genre) {
                  return InputChip(
                    label: Text(
                      genre,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    deleteIcon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    onDeleted: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedGenres.remove(genre);
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  );
                }),
                ActionChip(
                  avatar: const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'เลือกเพิ่ม',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  onPressed: _showGenrePickerSheet,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showGenrePickerSheet() {
    HapticFeedback.lightImpact();
    final allGenres = <String>{...AppData.genres, ..._selectedGenres}.toList();
    final tempSelected = List<String>.from(_selectedGenres);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'เลือกหมวดหมู่หนังสือ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'สามารถเลือกได้มากกว่า 1 หมวดหมู่',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (tempSelected.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setModalState(() {
                              tempSelected.clear();
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('ล้างทั้งหมด', style: TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Chips container
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: allGenres.map((genre) {
                          final isSelected = tempSelected.contains(genre);
                          return FilterChip(
                            label: Text(genre),
                            selected: isSelected,
                            onSelected: (selected) {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                if (selected) {
                                  tempSelected.add(genre);
                                } else {
                                  tempSelected.remove(genre);
                                }
                              });
                            },
                            backgroundColor: AppColors.secondary,
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.divider,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _selectedGenres
                                ..clear()
                                ..addAll(tempSelected);
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            tempSelected.isEmpty
                                ? 'ตกลง'
                                : 'บันทึก (${tempSelected.length} หมวดหมู่)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FAVORITE SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFavoriteSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFavorite
              ? const Color(0xFFD48B28).withValues(alpha: 0.6)
              : AppColors.divider.withValues(alpha: 0.6),
          width: _isFavorite ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFavorite
                ? const Color(0xFFD48B28).withValues(alpha: 0.12)
                : AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isFavorite = !_isFavorite);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isFavorite ? const Color(0xFFFCF3DE) : AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: _isFavorite ? const Color(0xFFD48B28) : AppColors.textSecondary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Favorite Book (หนังสือเล่มโปรด)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _isFavorite ? const Color(0xFFB57018) : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isFavorite
                            ? 'เพิ่มในรายการโปรดแล้ว (แสดงดาวสีทองบนชั้นหนังสือ)'
                            : 'แตะเพื่อเพิ่มเป็นหนังสือเล่มโปรด',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isFavorite,
                  activeThumbColor: const Color(0xFFD48B28),
                  activeTrackColor: const Color(0xFFFCF3DE),
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _isFavorite = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.secondary,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: AppColors.textPrimary,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.bookToEdit != null ? 'Edit Book Details' : 'Add New Book',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saveBook,
          child: const Text(
            'Save',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // COVER SECTION (Custom Image or Generated Color + Initial)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _pickCoverImage() async {
    HapticFeedback.lightImpact();
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _coverImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildCoverSection() {
    final title = _titleController.text.trim();
    final initial = title.isNotEmpty ? title[0].toUpperCase() : 'B';
    final baseColor = Color(_selectedColorValue);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Live Cover Preview (Click to change/upload image)
          GestureDetector(
            onTap: _pickCoverImage,
            child: Container(
              width: 110,
              height: 156,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _coverImageBytes == null
                    ? LinearGradient(
                        colors: [
                          baseColor,
                          baseColor.withValues(alpha: 0.72),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: _coverImageBytes != null
                        ? AppColors.textPrimary.withValues(alpha: 0.15)
                        : baseColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_coverImageBytes != null) ...[
                    // Custom Uploaded Image
                    Image.memory(
                      _coverImageBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    // Remove Image Button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _coverImageBytes = null);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    // Edit Overlay Badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ] else ...[
                    // Decorative patterns for placeholder
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -12,
                      bottom: -12,
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_stories_rounded,
                                size: 24,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 24,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Camera icon badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Upload / Change Image CTA button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickCoverImage,
                icon: Icon(
                  _coverImageBytes != null
                      ? Icons.photo_library_rounded
                      : Icons.add_photo_alternate_rounded,
                  size: 16,
                ),
                label: Text(
                  _coverImageBytes != null ? 'Change Cover' : 'Upload Cover Image',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_coverImageBytes != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _coverImageBytes = null);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                  label: const Text(
                    'Remove',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),

          // Color Palette Swatches (visible when no image is uploaded)
          if (_coverImageBytes == null) ...[
            const SizedBox(height: 16),
            const Text(
              'Or Choose Cover Color',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _coverColors.map((colorValue) {
                final isSelected = _selectedColorValue == colorValue;
                final color = Color(colorValue);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedColorValue = colorValue);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECTION CARD WRAPPER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TEXT FIELD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.secondary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLISHER DROPDOWN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPublisherDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Publisher',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            GestureDetector(
              onTap: _showAddNewPublisherDialog,
              child: const Text(
                '+ Add new',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedPublisher),
          initialValue: AppData.publishers.contains(_selectedPublisher)
              ? _selectedPublisher
              : (AppData.publishers.isNotEmpty ? AppData.publishers.first : null),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.business_rounded, size: 18, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.secondary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          items: [
            ...AppData.publishers.map((publisher) {
              return DropdownMenuItem<String>(
                value: publisher,
                child: Text(
                  publisher,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            const DropdownMenuItem<String>(
              value: '__add_new__',
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Add new publisher...',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (val) {
            if (val == '__add_new__') {
              _showAddNewPublisherDialog();
            } else if (val != null) {
              setState(() => _selectedPublisher = val);
            }
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STATUS OPTION BUTTON (Finished & Reading only)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStatusOption({
    required BookStatus status,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedStatus == status;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedStatus = status);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.secondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CALCULATED STAR ROW (Display-only for Overall Rating)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCalculatedStarRow({
    required double rating,
    required double starSize,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData icon;
        Color color;

        if (rating >= starValue) {
          icon = Icons.star_rounded;
          color = AppColors.starActive;
        } else if (rating >= starValue - 0.7) {
          icon = Icons.star_half_rounded;
          color = AppColors.starActive;
        } else {
          icon = Icons.star_border_rounded;
          color = AppColors.starInactive;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(icon, size: starSize, color: color),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // INTERACTIVE STAR ROW (For Topic Ratings)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildInteractiveStarRow({
    required double rating,
    required ValueChanged<double> onChanged,
    required double starSize,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = (index + 1).toDouble();
        final isFilled = rating >= starValue;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(starValue);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              isFilled ? Icons.star_rounded : Icons.star_border_rounded,
              size: starSize,
              color: isFilled ? AppColors.starActive : AppColors.starInactive,
            ),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SAVE BUTTON
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _saveBook,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Text(
              'Save to Bookshelf',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
