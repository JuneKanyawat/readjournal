/// Global app data and customized lists (Publishers, Rating Topics)
class AppData {
  AppData._();

  /// Shared list of publishers that users can manage in Settings and select in Add Book
  static final List<String> publishers = [
    'Penguin Random House',
    'HarperCollins',
    'Simon & Schuster',
    'Bloomsbury',
    'Tor Books',
  ];

  /// Shared list of rating topics
  static final List<String> ratingTopics = [
    'Story',
    'Character',
    'Writing Style',
    'Plot Twist',
    'Smut',
  ];
}
