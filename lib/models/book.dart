class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.totalCopies,
  });

  final String id;
  final String title;
  final String author;
  final int totalCopies;
}
