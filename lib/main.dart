import 'package:flutter/material.dart';

import 'data/sample_data.dart';
import 'screens/books_screen.dart';
import 'services/library_service.dart';

void main() {
  runApp(
    LibraryApp(
      service: LibraryService(books: sampleBooks, members: sampleMembers),
    ),
  );
}

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key, required this.service});

  final LibraryService service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Library Loans',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: BooksScreen(service: service),
    );
  }
}
