import 'package:flutter/material.dart';

import '../services/library_service.dart';

/// Lists all books for the selected member, with Borrow / Return buttons.
class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key, required this.service});

  final LibraryService service;

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  late String _memberId = widget.service.members.first.id;

  LibraryService get _service => widget.service;

  void _run(void Function() action, String successMessage) {
    try {
      setState(action);
      _showMessage(successMessage);
    } on LoanException catch (e) {
      _showMessage(e.message);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final borrowedIds = _service
        .activeLoansFor(_memberId)
        .map((l) => l.bookId)
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          DropdownButton<String>(
            key: const Key('memberPicker'),
            value: _memberId,
            items: [
              for (final m in _service.members)
                DropdownMenuItem(value: m.id, child: Text(m.name)),
            ],
            onChanged: (id) => setState(() => _memberId = id!),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        children: [
          for (final book in _service.books)
            ListTile(
              key: Key('book-${book.id}'),
              title: Text(book.title),
              subtitle: Text(
                '${book.author} · ${_service.availableCopies(book.id)} of '
                '${book.totalCopies} available',
              ),
              trailing: borrowedIds.contains(book.id)
                  ? OutlinedButton(
                      onPressed: () => _run(
                        () => _service.returnBook(
                          memberId: _memberId,
                          bookId: book.id,
                        ),
                        'Returned "${book.title}"',
                      ),
                      child: const Text('Return'),
                    )
                  : FilledButton(
                      onPressed: () => _run(
                        () => _service.borrow(
                          memberId: _memberId,
                          bookId: book.id,
                        ),
                        'Borrowed "${book.title}"',
                      ),
                      child: const Text('Borrow'),
                    ),
            ),
        ],
      ),
    );
  }
}
