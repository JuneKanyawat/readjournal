import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/book.dart';
import '../services/firestore_service.dart';
import 'add_book_screen.dart';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  // ─── State ──────────────────────────────────────────────────────
  bool _isGridView = true;
  String _searchQuery = '';
  String _sortBy = 'dateFinished'; // dateFinished, ratingHighToLow
  double? _filterRating;

  List<Book> _books = [];
  bool _isLoading = true;
  StreamSubscription<List<Book>>? _booksSubscription;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _booksSubscription = FirestoreService.getBooksStream().listen((books) {
      if (mounted) {
        setState(() {
          _books = books;
          _isLoading = false;
        });
      }
    }, onError: (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final isScrolled = _scrollController.offset > 100;
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      HapticFeedback.lightImpact();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _booksSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─── Filtered & Sorted Books ───────────────────────────────────
  List<Book> get _filteredBooks {
    List<Book> books = List.from(_books);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      books = books.where((b) =>
        b.title.toLowerCase().contains(q) ||
        b.author.toLowerCase().contains(q) ||
        b.publisher.toLowerCase().contains(q)
      ).toList();
    }

    // Filter by minimum rating
    if (_filterRating != null) {
      books = books.where((b) => b.overallRating >= _filterRating!).toList();
    }

    // Sort
    if (_sortBy == 'ratingHighToLow') {
      books.sort((a, b) => b.overallRating.compareTo(a.overallRating));
    } else {
      // dateFinished (newest first, null dates at the end)
      books.sort((a, b) {
        if (a.dateFinished == null && b.dateFinished == null) return 0;
        if (a.dateFinished == null) return 1;
        if (b.dateFinished == null) return -1;
        return b.dateFinished!.compareTo(a.dateFinished!);
      });
    }

    return books;
  }

  // ─── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filteredBooks = _filteredBooks;

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: PrimaryScrollController(
        controller: _scrollController,
        child: SafeArea(
          child: Column(
            children: [
              // ─── Header ──────────────────────────────────────────
              _buildHeader(),

              // ─── Search + Filter Row ─────────────────────────────
              _buildSearchAndFilterRow(),

              // ─── Book Count ──────────────────────────────────────
              _buildBookCount(filteredBooks.length),

              // ─── Book List/Grid ──────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : filteredBooks.isEmpty
                        ? _buildEmptyState()
                        : _buildBookDisplay(filteredBooks),
              ),
            ],
          ),
        ),
      ),

      // ─── Floating Action Button ────────────────────────────────
      floatingActionButton: _buildFAB(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _scrollToTop,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
        child: Row(
          children: [
            // Title
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _scrollToTop,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'My Library',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (_isScrolled) ...[
                          const SizedBox(width: 8),
                          AnimatedOpacity(
                            opacity: _isScrolled ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isScrolled
                          ? 'Tap to scroll to top'
                          : '${_books.length} books in collection',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _isScrolled ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // View Switcher
            _buildViewSwitcher(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VIEW SWITCHER (Grid / List toggle)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildViewSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewToggle(
            icon: Icons.grid_view_rounded,
            isActive: _isGridView,
            onTap: () => setState(() => _isGridView = true),
          ),
          _buildViewToggle(
            icon: Icons.view_list_rounded,
            isActive: !_isGridView,
            onTap: () => setState(() => _isGridView = false),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SEARCH & FILTER ROW
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSearchAndFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search title, author, publisher...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _searchFocusNode.unfocus();
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Filter & Sort Button
          GestureDetector(
            onTap: _showFilterSortSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: (_filterRating != null || _sortBy != 'dateFinished')
                    ? AppColors.primary
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (_filterRating != null || _sortBy != 'dateFinished')
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.textPrimary.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: (_filterRating != null || _sortBy != 'dateFinished')
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FILTER & SORT BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════
  void _showFilterSortSheet() {
    HapticFeedback.lightImpact();

    String tempSort = _sortBy;
    double? tempRating = _filterRating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title Row
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 22, color: AppColors.primary),
                        const SizedBox(width: 10),
                        const Text(
                          'Filter & Sort',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        // Reset
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempSort = 'dateFinished';
                              tempRating = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ─── Sort By ──────────────────────────────────
                    const Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildSortChip(
                          label: 'Date Finished',
                          icon: Icons.calendar_today_rounded,
                          isSelected: tempSort == 'dateFinished',
                          onTap: () => setModalState(() => tempSort = 'dateFinished'),
                        ),
                        const SizedBox(width: 10),
                        _buildSortChip(
                          label: 'Rating ↓',
                          icon: Icons.star_rounded,
                          isSelected: tempSort == 'ratingHighToLow',
                          onTap: () => setModalState(() => tempSort = 'ratingHighToLow'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ─── Filter by Rating ─────────────────────────
                    const Text(
                      'Minimum Rating',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildRatingFilterChip(
                          label: 'Any',
                          isSelected: tempRating == null,
                          onTap: () => setModalState(() => tempRating = null),
                        ),
                        for (int i = 3; i <= 5; i++) ...[
                          const SizedBox(width: 8),
                          _buildRatingFilterChip(
                            label: '$i+ ★',
                            isSelected: tempRating == i.toDouble(),
                            onTap: () => setModalState(() => tempRating = i.toDouble()),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ─── Apply Button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _sortBy = tempSort;
                              _filterRating = tempRating;
                            });
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Apply Filters',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.secondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildRatingFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.starActive.withValues(alpha: 0.12) : AppColors.secondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.starActive : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.starActive : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }



  // ═══════════════════════════════════════════════════════════════
  // BOOK COUNT + Active Filters
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBookCount(int count) {
    final hasActiveFilters =
        _filterRating != null || _sortBy != 'dateFinished';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _scrollToTop,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
        child: Row(
          children: [
            Text(
              '$count ${count == 1 ? 'book' : 'books'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _filterRating = null;
                  _sortBy = 'dateFinished';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      'Clear filters',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOOK DISPLAY (Grid or List)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBookDisplay(List<Book> books) {
    if (_isGridView) {
      return _buildGridView(books);
    } else {
      return _buildListView(books);
    }
  }

  // ─── GRID VIEW ─────────────────────────────────────────────────
  Widget _buildGridView(List<Book> books) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.70,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        return _buildGridCard(books[index], index);
      },
    );
  }

  Widget _buildGridCard(Book book, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showBookDetail(book),
        onLongPress: () => _showBookOptions(book),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildBookCover(
                book,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            // Favorite Star Badge (Top Left)
            if (book.isFavorite)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Color(0xFFF5A623),
                  ),
                ),
              ),
            // Eye Toggle Icon for Blur (Bottom Right)
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleBlur(book),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    book.isBlurred
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LIST VIEW ─────────────────────────────────────────────────
  Widget _buildListView(List<Book> books) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: books.length,
      itemBuilder: (context, index) {
        return _buildListCard(books[index], index);
      },
    );
  }

  Widget _buildListCard(Book book, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showBookDetail(book),
        onLongPress: () => _showBookOptions(book),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book Cover Thumbnail
                SizedBox(
                  width: 80,
                  height: 115,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildBookCover(
                          book,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      if (book.isFavorite)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Color(0xFFF5A623),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Book Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Author & Publisher
                      Text(
                        '${book.author} · ${book.publisher}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Custom Ratings Breakdown
                      if (book.customRatings.isNotEmpty)
                        _buildCustomRatings(book.customRatings),

                      // Completion Date
                      if (book.dateFinished != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 13,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Finished ${_formatDate(book.dateFinished!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Status badge for non-finished books
                      if (book.status == BookStatus.reading)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildStatusBadge('Reading', Icons.auto_stories_rounded, AppColors.primary),
                        ),
                      if (book.status == BookStatus.wishlist)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildStatusBadge('Wishlist', Icons.bookmark_outline_rounded, AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Custom Ratings Breakdown (List View) ──────────────────────
  Widget _buildCustomRatings(Map<String, double> ratings) {
    final entries = ratings.entries.take(3).toList();
    return Row(
      children: entries.map((entry) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    ...List.generate(5, (i) {
                      return Icon(
                        i < entry.value ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 11,
                        color: i < entry.value
                            ? AppColors.starActive
                            : AppColors.starInactive,
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED COMPONENTS
  // ═══════════════════════════════════════════════════════════════

  // ─── Book Cover (placeholder with gradient + initial or custom image) ──
  Widget _buildBookCover(
    Book book, {
    required BorderRadius borderRadius,
    bool allowBlur = true,
  }) {
    Widget imageContent;

    if (book.coverImageBytes != null) {
      imageContent = Image.memory(
        book.coverImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      final baseColor = Color(book.coverColorValue);
      imageContent = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              baseColor,
              baseColor.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative pattern
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              left: -15,
              bottom: -15,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Book icon
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 24,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 6),
                      // Initial Letter
                      Text(
                        book.coverInitial ?? (book.title.isNotEmpty ? book.title[0] : 'B'),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Spine-like divider
                      Container(
                        width: 24,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (allowBlur && book.isBlurred) {
      imageContent = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: imageContent,
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: imageContent,
    );
  }



  // ═══════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    final isTrulyEmpty = _books.isEmpty && _searchQuery.isEmpty && _filterRating == null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cozy illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Decorative ring
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        width: 2,
                      ),
                    ),
                  ),
                  // Books icon
                  Icon(
                    Icons.menu_book_rounded,
                    size: 48,
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isTrulyEmpty ? 'Your bookshelf is empty' : 'No books found in\nthis shelf',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isTrulyEmpty
                  ? 'Tap the + button to add your first book'
                  : 'Try adjusting your search or filters',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (isTrulyEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _navigateToAddBook,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add a Book', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FLOATING ACTION BUTTON
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFAB() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _navigateToAddBook,
          borderRadius: BorderRadius.circular(18),
          child: const Icon(
            Icons.add_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAddBook() async {
    HapticFeedback.mediumImpact();
    final newBook = await Navigator.push<Book>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddBookScreen(),
      ),
    );

    if (newBook != null && mounted) {
      try {
        await FirestoreService.addBook(newBook);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved "${newBook.title}" to Firestore!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save book: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BLUR & FAVORITE TOGGLES
  // ═══════════════════════════════════════════════════════════════
  void _toggleBlur(Book book) {
    HapticFeedback.lightImpact();
    final newBlurred = !book.isBlurred;
    setState(() {
      final index = _books.indexWhere((b) => b.id == book.id);
      if (index != -1) {
        _books[index] = _books[index].copyWith(isBlurred: newBlurred);
      }
    });
    FirestoreService.toggleBlur(book.id, newBlurred);
  }

  void _toggleFavorite(Book book) {
    HapticFeedback.lightImpact();
    final newFavorite = !book.isFavorite;
    setState(() {
      final index = _books.indexWhere((b) => b.id == book.id);
      if (index != -1) {
        _books[index] = _books[index].copyWith(isFavorite: newFavorite);
      }
    });
    FirestoreService.toggleFavorite(book.id, newFavorite);
  }

  // ═══════════════════════════════════════════════════════════════
  // BOOK DETAIL MODAL (Matching UI Mockup)
  // ═══════════════════════════════════════════════════════════════
  void _showBookDetail(Book book) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Find current book in case favorite or blur changed
            final currentBook = _books.firstWhere(
              (b) => b.id == book.id,
              orElse: () => book,
            );

            // Determine status badge colors & text
            Color statusBg;
            Color statusTextColor;
            String statusLabel;
            switch (currentBook.status) {
              case BookStatus.finished:
                statusBg = const Color(0xFFD4F7E6);
                statusTextColor = const Color(0xFF137A4B);
                statusLabel = 'อ่านจบแล้ว';
                break;
              case BookStatus.reading:
                statusBg = const Color(0xFFFFF3D6);
                statusTextColor = const Color(0xFFB57000);
                statusLabel = 'กำลังอ่าน';
                break;
              case BookStatus.wishlist:
                statusBg = const Color(0xFFEFEFEF);
                statusTextColor = const Color(0xFF666666);
                statusLabel = 'อยากอ่าน';
                break;
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Top Header Row with title and 'X' close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'รายละเอียดหนังสือ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover + Book Info Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cover Thumbnail
                              SizedBox(
                                width: 110,
                                height: 155,
                                child: _buildBookCover(
                                  currentBook,
                                  borderRadius: BorderRadius.circular(16),
                                  allowBlur: false, // show clearly in detail
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Info Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title
                                    Text(
                                      currentBook.title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Publisher
                                    Text(
                                      'สำนักพิมพ์: ${currentBook.publisher.isNotEmpty ? currentBook.publisher : currentBook.author}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Status Badge Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: statusTextColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Date Finished
                                    if (currentBook.dateFinished != null)
                                      Text(
                                        'อ่านจบเมื่อ: ${currentBook.dateFinished!.year}-${currentBook.dateFinished!.month.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Genre Tags
                          if (currentBook.genres.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: currentBook.genres.map((genre) {
                                return _buildDetailGenreChip(genre);
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Ratings Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.divider.withValues(alpha: 0.8),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ratings Header
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 20,
                                      color: Color(0xFFF5A623),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'คะแนนคะแนนประเมิน (Ratings)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Ratings Grid (2 columns)
                                _buildDetailRatingsGrid(currentBook),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Action Buttons
                          Row(
                            children: [
                              // Favorite Toggle Button
                              GestureDetector(
                                onTap: () {
                                  _toggleFavorite(currentBook);
                                  setModalState(() {});
                                },
                                child: Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    color: currentBook.isFavorite
                                        ? const Color(0xFFFFF6E5)
                                        : AppColors.secondary,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: currentBook.isFavorite
                                          ? const Color(0xFFF5A623)
                                          : AppColors.divider,
                                    ),
                                  ),
                                  child: Icon(
                                    currentBook.isFavorite
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: currentBook.isFavorite
                                        ? const Color(0xFFF5A623)
                                        : AppColors.textSecondary,
                                    size: 24,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // Edit Button (Primary)
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _navigateToEditBook(currentBook);
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  label: const Text(
                                    'แก้ไขข้อมูล (Edit)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // Delete Button
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _confirmDeleteBook(currentBook);
                                },
                                child: Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCC5B5B).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFCC5B5B),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailGenreChip(String genre) {
    final colors = [
      {'bg': const Color(0xFFFFE8E4), 'text': const Color(0xFFB33A3A)},
      {'bg': const Color(0xFFEADEFF), 'text': const Color(0xFF5B34B3)},
      {'bg': const Color(0xFFFBE4F4), 'text': const Color(0xFF8C2B7A)},
      {'bg': const Color(0xFFE4F3FB), 'text': const Color(0xFF1D6F9A)},
      {'bg': const Color(0xFFE6F8EE), 'text': const Color(0xFF1B8A4D)},
      {'bg': const Color(0xFFFFF4DF), 'text': const Color(0xFFAC6B00)},
    ];
    final colorMap = colors[genre.hashCode.abs() % colors.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorMap['bg'],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        genre,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colorMap['text'],
        ),
      ),
    );
  }

  Widget _buildDetailRatingsGrid(Book book) {
    final entries = book.customRatings.entries.toList();
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overall',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
                const SizedBox(width: 4),
                Text(
                  '${book.overallRating.toStringAsFixed(1)}/5',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFFE59400),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: entries.map((entry) {
            final val = entry.value;
            final valStr = val.truncateToDouble() == val ? '${val.toInt()}' : val.toStringAsFixed(1);
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
                        const SizedBox(width: 3),
                        Text(
                          '$valStr/5',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE59400),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _navigateToEditBook(Book book) async {
    HapticFeedback.mediumImpact();
    final updatedBook = await Navigator.push<Book>(
      context,
      MaterialPageRoute(
        builder: (context) => AddBookScreen(bookToEdit: book),
      ),
    );

    if (updatedBook != null && mounted) {
      try {
        setState(() {
          final idx = _books.indexWhere((b) => b.id == updatedBook.id);
          if (idx != -1) {
            _books[idx] = updatedBook;
          }
        });
        await FirestoreService.updateBook(updatedBook);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Updated "${updatedBook.title}" successfully!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update book: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteBook(Book book) async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFCC5B5B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFCC5B5B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Book',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${book.title}" from your bookshelf?',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC5B5B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        setState(() {
          _books.removeWhere((b) => b.id == book.id);
        });
        await FirestoreService.deleteBook(book.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${book.title}"'),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete book: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBookOptions(Book book) {
    _showBookDetail(book);
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
