import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book.dart';
import '../constants/app_data.dart';

/// Service managing Cloud Firestore persistence for books and user settings
class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Currently authenticated user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  /// Firestore books collection reference: users/{uid}/books
  static CollectionReference<Map<String, dynamic>>? get _booksRef {
    final uid = currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('books');
  }

  /// Firestore settings document reference: users/{uid}/settings/preferences
  static DocumentReference<Map<String, dynamic>>? get _settingsRef {
    final uid = currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('settings').doc('preferences');
  }

  // ═══════════════════════════════════════════════════════════════
  // BOOKS
  // ═══════════════════════════════════════════════════════════════

  /// Real-time stream of books for the active user
  static Stream<List<Book>> getBooksStream() {
    final ref = _booksRef;
    if (ref == null) return Stream.value([]);

    return ref.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Book.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Add a new book to the user's Firestore collection
  static Future<String> addBook(Book book) async {
    final ref = _booksRef;
    if (ref == null) throw Exception('Cannot add book: User not logged in.');

    final docRef = ref.doc();
    final data = book.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);
    return docRef.id;
  }

  /// Update an existing book in Firestore
  static Future<void> updateBook(Book book) async {
    final ref = _booksRef;
    if (ref == null) throw Exception('Cannot update book: User not logged in.');

    final data = book.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await ref.doc(book.id).update(data);
  }

  /// Delete a book from Firestore
  static Future<void> deleteBook(String bookId) async {
    final ref = _booksRef;
    if (ref == null) throw Exception('Cannot delete book: User not logged in.');

    await ref.doc(bookId).delete();
  }

  /// Seed sample books into user's Firestore collection (optional convenience)
  static Future<void> seedSampleBooks() async {
    final ref = _booksRef;
    if (ref == null) return;

    final batch = _firestore.batch();
    for (final book in sampleBooks) {
      final docRef = ref.doc();
      final data = book.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(docRef, data);
    }
    await batch.commit();
  }

  // ═══════════════════════════════════════════════════════════════
  // SETTINGS (Rating Criteria & Publishers)
  // ═══════════════════════════════════════════════════════════════

  /// Real-time stream of user preferences from Firestore
  static Stream<DocumentSnapshot<Map<String, dynamic>>>? getSettingsStream() {
    return _settingsRef?.snapshots();
  }

  /// Initialize user settings in Firestore if not yet saved, or sync to AppData
  static Future<void> initUserSettingsIfNeeded() async {
    final ref = _settingsRef;
    if (ref == null) return;

    try {
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'publishers': AppData.publishers,
          'ratingTopics': AppData.ratingTopics,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data();
        if (data != null) {
          syncToAppData(data);
        }
      }
    } catch (e) {
      // Ignore network or permission errors during initial load
    }
  }

  /// Synchronize Firestore preferences to in-memory AppData constants
  static void syncToAppData(Map<String, dynamic> data) {
    if (data['publishers'] is List) {
      final list = (data['publishers'] as List).map((e) => e.toString()).toList();
      if (list.isNotEmpty) {
        AppData.publishers
          ..clear()
          ..addAll(list);
      }
    }
    if (data['ratingTopics'] is List) {
      final list = (data['ratingTopics'] as List).map((e) => e.toString()).toList();
      if (list.isNotEmpty) {
        AppData.ratingTopics
          ..clear()
          ..addAll(list);
      }
    }
  }

  /// Add a publisher to Firestore and memory
  static Future<void> addPublisher(String publisher) async {
    final trimmed = publisher.trim();
    if (trimmed.isEmpty) return;

    if (!AppData.publishers.contains(trimmed)) {
      AppData.publishers.add(trimmed);
    }

    final ref = _settingsRef;
    if (ref == null) return;

    await ref.set({
      'publishers': FieldValue.arrayUnion([trimmed]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove a publisher from Firestore and memory
  static Future<void> removePublisher(String publisher) async {
    AppData.publishers.remove(publisher);

    final ref = _settingsRef;
    if (ref == null) return;

    await ref.set({
      'publishers': FieldValue.arrayRemove([publisher]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update entire publisher list in Firestore and memory
  static Future<void> updatePublishers(List<String> publishers) async {
    AppData.publishers
      ..clear()
      ..addAll(publishers);

    final ref = _settingsRef;
    if (ref == null) return;

    await ref.set({
      'publishers': publishers,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Add a rating topic to Firestore and memory
  static Future<void> addRatingTopic(String topic) async {
    final trimmed = topic.trim();
    if (trimmed.isEmpty) return;

    if (!AppData.ratingTopics.contains(trimmed)) {
      AppData.ratingTopics.add(trimmed);
    }

    final ref = _settingsRef;
    if (ref == null) return;

    await ref.set({
      'ratingTopics': FieldValue.arrayUnion([trimmed]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove a rating topic from Firestore and memory
  static Future<void> removeRatingTopic(String topic) async {
    AppData.ratingTopics.remove(topic);

    final ref = _settingsRef;
    if (ref == null) return;

    await ref.set({
      'ratingTopics': FieldValue.arrayRemove([topic]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update entire rating topics list in Firestore and memory
  static Future<void> updateRatingTopics(List<String> topics) async {
    AppData.ratingTopics
      ..clear()
      ..addAll(topics);

    final ref = _settingsRef;
    if (ref == null) return;

    await ref.set({
      'ratingTopics': topics,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
