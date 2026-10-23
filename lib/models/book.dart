import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Book model for the ReadJournal app.
class Book {
  final String id;
  final String title;
  final String author;
  final String publisher;
  final int coverColorValue; // placeholder color for book cover
  final double overallRating;
  final Map<String, double> customRatings; // e.g. Story: 4, Smut: 3
  final List<String> genres;
  final BookStatus status;
  final DateTime? dateFinished;
  final String? coverInitial; // first letter for placeholder cover
  final Uint8List? coverImageBytes; // custom user uploaded cover image

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.publisher,
    required this.coverColorValue,
    required this.overallRating,
    required this.customRatings,
    this.genres = const [],
    required this.status,
    this.dateFinished,
    this.coverInitial,
    this.coverImageBytes,
  });

  /// Convert Book object to Map for Firestore document storage
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'publisher': publisher,
      'coverColorValue': coverColorValue,
      'overallRating': overallRating,
      'customRatings': customRatings,
      'genres': genres,
      'status': status.name,
      'dateFinished': dateFinished != null ? Timestamp.fromDate(dateFinished!) : null,
      'coverInitial': coverInitial,
      'coverImageBase64': coverImageBytes != null ? base64Encode(coverImageBytes!) : null,
    };
  }

  /// Create Book object from Firestore document data
  factory Book.fromMap(String id, Map<String, dynamic> map) {
    DateTime? date;
    final df = map['dateFinished'];
    if (df is Timestamp) {
      date = df.toDate();
    } else if (df is String) {
      date = DateTime.tryParse(df);
    }

    Uint8List? imageBytes;
    final b64 = map['coverImageBase64'];
    if (b64 is String && b64.isNotEmpty) {
      try {
        imageBytes = base64Decode(b64);
      } catch (_) {}
    }

    BookStatus bookStatus = BookStatus.finished;
    final statusStr = map['status'];
    if (statusStr is String) {
      for (final s in BookStatus.values) {
        if (s.name == statusStr) {
          bookStatus = s;
          break;
        }
      }
    }

    final Map<String, double> parsedCustomRatings = {};
    if (map['customRatings'] is Map) {
      (map['customRatings'] as Map).forEach((k, v) {
        if (v is num) {
          parsedCustomRatings[k.toString()] = v.toDouble();
        }
      });
    }

    final List<String> parsedGenres = [];
    if (map['genres'] is List) {
      for (final g in map['genres'] as List) {
        if (g != null) parsedGenres.add(g.toString());
      }
    }

    return Book(
      id: id,
      title: map['title'] as String? ?? '',
      author: map['author'] as String? ?? '',
      publisher: map['publisher'] as String? ?? 'Independent',
      coverColorValue: (map['coverColorValue'] as num?)?.toInt() ?? 0xFF2B6777,
      overallRating: (map['overallRating'] as num?)?.toDouble() ?? 0.0,
      customRatings: parsedCustomRatings,
      genres: parsedGenres,
      status: bookStatus,
      dateFinished: date,
      coverInitial: map['coverInitial'] as String?,
      coverImageBytes: imageBytes,
    );
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? publisher,
    int? coverColorValue,
    double? overallRating,
    Map<String, double>? customRatings,
    List<String>? genres,
    BookStatus? status,
    DateTime? dateFinished,
    String? coverInitial,
    Uint8List? coverImageBytes,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      coverColorValue: coverColorValue ?? this.coverColorValue,
      overallRating: overallRating ?? this.overallRating,
      customRatings: customRatings ?? this.customRatings,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      dateFinished: dateFinished ?? this.dateFinished,
      coverInitial: coverInitial ?? this.coverInitial,
      coverImageBytes: coverImageBytes ?? this.coverImageBytes,
    );
  }
}

enum BookStatus { finished, reading, wishlist }

/// Sample book data for UI demonstration
final List<Book> sampleBooks = [
  Book(
    id: '1',
    title: 'The House in the Cerulean Sea',
    author: 'TJ Klune',
    publisher: 'Tor Books',
    coverColorValue: 0xFF2B6777,
    overallRating: 4.5,
    customRatings: {'Story': 5, 'Character': 5, 'Writing Style': 4, 'Plot Twist': 3, 'Smut': 1},
    genres: ['Fantasy', 'Romance'],
    status: BookStatus.finished,
    dateFinished: DateTime(2024, 12, 15),
    coverInitial: 'H',
  ),
  Book(
    id: '2',
    title: 'Fourth Wing',
    author: 'Rebecca Yarros',
    publisher: 'Penguin Random House',
    coverColorValue: 0xFF1A1A2E,
    overallRating: 4.0,
    customRatings: {'Story': 4, 'Character': 4, 'Writing Style': 3, 'Plot Twist': 5, 'Smut': 4},
    genres: ['Fantasy', 'Romance', 'Dark Fantasy'],
    status: BookStatus.finished,
    dateFinished: DateTime(2024, 11, 28),
    coverInitial: 'F',
  ),
  Book(
    id: '3',
    title: 'Twisted Love',
    author: 'Ana Huang',
    publisher: 'Bloom Books',
    coverColorValue: 0xFF8B1A1A,
    overallRating: 3.5,
    customRatings: {'Story': 3, 'Character': 4, 'Writing Style': 3, 'Plot Twist': 4, 'Smut': 5},
    genres: ['Romance', 'Slow Burn'],
    status: BookStatus.finished,
    dateFinished: DateTime(2024, 10, 5),
    coverInitial: 'T',
  ),
  Book(
    id: '4',
    title: 'A Court of Thorns and Roses',
    author: 'Sarah J. Maas',
    publisher: 'Bloomsbury',
    coverColorValue: 0xFF4A0E4E,
    overallRating: 4.0,
    customRatings: {'Story': 4, 'Character': 5, 'Writing Style': 4, 'Plot Twist': 4, 'Smut': 3},
    genres: ['Fantasy', 'Romance', 'Dark Fantasy'],
    status: BookStatus.reading,
    coverInitial: 'A',
  ),
  Book(
    id: '5',
    title: 'The Midnight Library',
    author: 'Matt Haig',
    publisher: 'Viking',
    coverColorValue: 0xFF0D1B2A,
    overallRating: 4.5,
    customRatings: {'Story': 5, 'Character': 4, 'Writing Style': 5, 'Plot Twist': 4, 'Smut': 0},
    genres: ['Sci-Fi', 'Fantasy'],
    status: BookStatus.reading,
    coverInitial: 'M',
  ),
  Book(
    id: '6',
    title: 'Iron Flame',
    author: 'Rebecca Yarros',
    publisher: 'Penguin Random House',
    coverColorValue: 0xFF8B4513,
    overallRating: 0,
    customRatings: {},
    genres: ['Fantasy', 'Romance'],
    status: BookStatus.wishlist,
    coverInitial: 'I',
  ),
  Book(
    id: '7',
    title: 'Onyx Storm',
    author: 'Rebecca Yarros',
    publisher: 'Penguin Random House',
    coverColorValue: 0xFF2F4F4F,
    overallRating: 0,
    customRatings: {},
    genres: ['Fantasy', 'Dark Fantasy'],
    status: BookStatus.wishlist,
    coverInitial: 'O',
  ),
  Book(
    id: '8',
    title: 'Things We Never Got Over',
    author: 'Lucy Score',
    publisher: 'Bloom Books',
    coverColorValue: 0xFFB8860B,
    overallRating: 4.0,
    customRatings: {'Story': 4, 'Character': 5, 'Writing Style': 4, 'Plot Twist': 3, 'Smut': 3},
    genres: ['Romance', 'Slow Burn'],
    status: BookStatus.finished,
    dateFinished: DateTime(2024, 9, 20),
    coverInitial: 'T',
  ),
  Book(
    id: '9',
    title: 'Haunting Adeline',
    author: 'H.D. Carlton',
    publisher: 'Independent',
    coverColorValue: 0xFF2C0735,
    overallRating: 3.5,
    customRatings: {'Story': 3, 'Character': 3, 'Writing Style': 3, 'Plot Twist': 4, 'Smut': 5},
    genres: ['Romance', 'Thriller', 'Dark Fantasy'],
    status: BookStatus.finished,
    dateFinished: DateTime(2024, 8, 14),
    coverInitial: 'H',
  ),
];
