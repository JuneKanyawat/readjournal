import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/book.dart';
import '../services/firestore_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _selectedYear = DateTime.now().year;

  // Toggle for genre features
  static const bool _enableGenres = true;

  // Month names for the 1-year chart
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Palette for Top Genres progress bars (matching user's design)
  static const List<Color> _genreColors = [
    Color(0xFFE07A5F), // Terracotta / Coral
    Color(0xFFB497D6), // Lilac / Purple
    Color(0xFFE898AC), // Pastel Rose
    Color(0xFFF4A261), // Warm Peach
    Color(0xFF81B29A), // Sage
    Color(0xFF8ECAE6), // Sky Blue
    Color(0xFFD4A373), // Warm Sand
    Color(0xFFE76F51), // Burnt Orange
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: StreamBuilder<List<Book>>(
          stream: FirestoreService.getBooksStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final allBooks = snapshot.data ?? [];
            final finishedBooks = allBooks.where((b) => b.status == BookStatus.finished).toList();

            return Column(
              children: [
                // Top Header (tappable to scroll to top)
                _buildHeader(),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    children: [
                      // 1. Summary Cards (Total Finished & Average Rating)
                      _buildSummaryCards(finishedBooks),

                      const SizedBox(height: 18),

                      // 2. 1-Year Monthly Reading Chart
                      _buildMonthlyChartCard(finishedBooks),

                      const SizedBox(height: 18),

                      // 3. Rating Topics Breakdown
                      _buildRatingTopicsCard(finishedBooks),

                      // 4. Top Genres Breakdown (ปิดการใช้งานชั่วคราว)
                      if (_enableGenres) ...[
                        const SizedBox(height: 18),
                        _buildTopGenresCard(finishedBooks),
                      ],

                      const SizedBox(height: 18),

                      // 5. Top-Rated Book Card
                      _buildTopRatedCard(finishedBooks),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _scrollToTop,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reading Stats',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ภาพรวมและสถิติการอ่านของคุณ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 1. SUMMARY CARDS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSummaryCards(List<Book> books) {
    final totalCount = books.length;
    double avgRating = 0.0;
    if (books.isNotEmpty) {
      final sum = books.fold<double>(0.0, (acc, b) => acc + b.overallRating);
      avgRating = (sum / books.length * 10).round() / 10.0;
    }

    return Row(
      children: [
        // Total Finished Books
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.menu_book_rounded,
            iconBg: const Color(0xFFFBECE4),
            iconColor: AppColors.primary,
            value: totalCount.toString(),
            label: 'อ่านจบทั้งหมด (เล่ม)',
          ),
        ),
        const SizedBox(width: 14),
        // Average Star Rating
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.star_rounded,
            iconBg: const Color(0xFFFCF3DE),
            iconColor: const Color(0xFFD48B28),
            value: totalCount > 0 ? avgRating.toStringAsFixed(1) : '-',
            label: 'คะแนนดาวเฉลี่ยรวม',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. 1-YEAR MONTHLY READING CHART
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMonthlyChartCard(List<Book> books) {
    // Calculate monthly books for _selectedYear
    final monthlyCounts = List<int>.filled(12, 0);
    int totalYearBooks = 0;

    for (final book in books) {
      if (book.dateFinished != null && book.dateFinished!.year == _selectedYear) {
        final monthIdx = book.dateFinished!.month - 1;
        if (monthIdx >= 0 && monthIdx < 12) {
          monthlyCounts[monthIdx]++;
          totalYearBooks++;
        }
      }
    }

    final maxCount = monthlyCounts.reduce(max);
    final chartMax = max(maxCount, 4);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
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
          // Header Row with Year Navigator
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'สถิติการอ่านรายปี (Monthly)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'อ่านจบ $totalYearBooks เล่ม ในปี $_selectedYear',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              // Year Navigator
              Container(
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedYear--);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '$_selectedYear',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedYear++);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 12-Month Bar Chart
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (index) {
                final count = monthlyCounts[index];
                final normalizedHeight = count / chartMax;
                final isCurrentMonth = DateTime.now().year == _selectedYear && (DateTime.now().month - 1) == index;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Count label above bar
                        SizedBox(
                          height: 16,
                          child: count > 0
                              ? Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrentMonth ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        // Bar Column
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final availableHeight = constraints.maxHeight;
                              final barHeight = count > 0
                                  ? max(normalizedHeight * availableHeight, 10.0)
                                  : 4.0;

                              return Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                  height: barHeight,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: count > 0
                                        ? LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: isCurrentMonth
                                                ? [AppColors.primary, AppColors.primaryDark]
                                                : [
                                                    AppColors.primary.withValues(alpha: 0.85),
                                                    AppColors.primary.withValues(alpha: 0.65),
                                                  ],
                                          )
                                        : null,
                                    color: count == 0 ? AppColors.divider.withValues(alpha: 0.5) : null,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: count > 0 && isCurrentMonth
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Month label
                        Text(
                          _monthNames[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isCurrentMonth ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrentMonth ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. RATING TOPICS BREAKDOWN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRatingTopicsCard(List<Book> books) {
    // Compute average rating for each topic across all books
    final Map<String, List<double>> topicScores = {};

    for (final book in books) {
      book.customRatings.forEach((topic, score) {
        topicScores.putIfAbsent(topic, () => []).add(score);
      });
    }

    final Map<String, double> topicAverages = {};
    topicScores.forEach((topic, scores) {
      if (scores.isNotEmpty) {
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        topicAverages[topic] = (avg * 10).round() / 10.0;
      }
    });

    final sortedTopics = topicAverages.keys.toList()
      ..sort((a, b) => topicAverages[b]!.compareTo(topicAverages[a]!));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
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
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'คะแนนเฉลี่ยแยกตามหัวข้อ (Rating Topics)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.bar_chart_rounded,
                size: 20,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (sortedTopics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'ยังไม่มีข้อมูลคะแนนตามหัวข้อ',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            ...sortedTopics.map((topic) {
              final avg = topicAverages[topic]!;
              final progress = (avg / 5.0).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            topic,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFD48B28)),
                        const SizedBox(width: 4),
                        Text(
                          '${avg.toStringAsFixed(1)} / 5',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD48B28),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFF3EFEA),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. TOP GENRES BREAKDOWN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTopGenresCard(List<Book> books) {
    // Count books per genre
    final Map<String, int> genreCounts = {};
    for (final book in books) {
      for (final genre in book.genres) {
        final trimmed = genre.trim();
        if (trimmed.isNotEmpty) {
          genreCounts[trimmed] = (genreCounts[trimmed] ?? 0) + 1;
        }
      }
    }

    final sortedGenres = genreCounts.keys.toList()
      ..sort((a, b) => genreCounts[b]!.compareTo(genreCounts[a]!));

    final totalGenreEntries = genreCounts.values.fold<int>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
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
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'สัดส่วนประเภทหนังสือ (Top Genres)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.pie_chart_outline_rounded,
                size: 20,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (sortedGenres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'ยังไม่มีข้อมูลประเภทหนังสือ (ลองเพิ่ม Genre ในหนังสือ)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            ...sortedGenres.asMap().entries.map((entry) {
              final index = entry.key;
              final genre = entry.value;
              final count = genreCounts[genre]!;
              final color = _genreColors[index % _genreColors.length];
              final progress = totalGenreEntries > 0 ? (count / totalGenreEntries).clamp(0.0, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            genre,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '$count เล่ม',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. TOP-RATED BOOK CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTopRatedCard(List<Book> books) {
    if (books.isEmpty) return const SizedBox.shrink();

    // Find the highest rated book
    Book topBook = books.first;
    for (final b in books) {
      if (b.overallRating > topBook.overallRating) {
        topBook = b;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF1EB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1DECE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'หนังสือระดับ Top-Rated ของคุณ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD48B28)),
                    const SizedBox(width: 3),
                    Text(
                      topBook.overallRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Cover Thumbnail
              SizedBox(
                width: 58,
                height: 80,
                child: _buildBookCover(topBook),
              ),
              const SizedBox(width: 14),
              // Book Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topBook.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'สำนักพิมพ์: ${topBook.publisher}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    if (topBook.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ผู้แต่ง: ${topBook.author}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOOK COVER THUMBNAIL HELPER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBookCover(Book book) {
    final borderRadius = BorderRadius.circular(10);

    if (book.coverImageBytes != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.memory(
          book.coverImageBytes!,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => _buildPlaceholderCover(book, borderRadius),
        ),
      );
    }

    return _buildPlaceholderCover(book, borderRadius);
  }

  Widget _buildPlaceholderCover(Book book, BorderRadius borderRadius) {
    final initial = (book.coverInitial != null && book.coverInitial!.isNotEmpty)
        ? book.coverInitial!
        : (book.title.isNotEmpty ? book.title[0].toUpperCase() : 'B');

    return Container(
      decoration: BoxDecoration(
        color: Color(book.coverColorValue),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
