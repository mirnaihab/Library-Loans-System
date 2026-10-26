import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/reservation.dart';
import '../services/library_service.dart';

/// Lists all books for the selected member, with one action per book.
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
    final activeLoans = _service.activeLoansFor(_memberId);
    final borrowedIds = activeLoans.map((l) => l.bookId).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          Center(
            key: const Key('borrowCount'),
            child: Text(
              '${activeLoans.length} of ${LibraryService.borrowingLimit} '
              'books borrowed',
            ),
          ),
          const SizedBox(width: 16),
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
      body: Column(
        children: [
          ListTile(
            key: const Key('outstandingFees'),
            title: Text(
              'Outstanding fees: ${_service.outstandingFees(_memberId)} EGP',
            ),
            trailing: OutlinedButton(
              key: const Key('payFees'),
              onPressed: () =>
                  _run(() => _service.payFees(_memberId), 'Fees paid'),
              child: const Text('Mark as paid'),
            ),
          ),
          const Divider(),
          Expanded(child: _bookList(borrowedIds)),
        ],
      ),
    );
  }

  Widget _bookList(Set<String> borrowedIds) {
    return ListView(
      children: [
        for (final book in _service.books) _bookTile(book, borrowedIds),
      ],
    );
  }

  Widget _bookTile(Book book, Set<String> borrowedIds) {
    final status = _service.reservationStatus(
      memberId: _memberId,
      bookId: book.id,
    );
    return ListTile(
      key: Key('book-${book.id}'),
      title: Text(book.title),
      subtitle: Text(
        [
          '${book.author} · ${_service.availableCopies(book.id)} of '
              '${book.totalCopies} available',
          ?_reservationText(status),
        ].join(' · '),
      ),
      trailing: _actionFor(book, borrowedIds, status),
    );
  }

  static String? _reservationText(ReservationStatus? status) =>
      switch (status) {
        Waiting(:final position) => 'Reserved · #$position in queue',
        OnHold(:final lastDay) =>
          'On hold for you until ${lastDay.day}/${lastDay.month}',
        null => null,
      };

  /// The one action the selected member can take on [book], if any.
  Widget? _actionFor(
    Book book,
    Set<String> borrowedIds,
    ReservationStatus? status,
  ) {
    if (borrowedIds.contains(book.id)) {
      return OutlinedButton(
        onPressed: () => _run(
          () => _service.returnBook(memberId: _memberId, bookId: book.id),
          'Returned "${book.title}"',
        ),
        child: const Text('Return'),
      );
    }
    if (status is OnHold) {
      return FilledButton(
        onPressed: () => _run(
          () => _service.borrow(memberId: _memberId, bookId: book.id),
          'Borrowed "${book.title}"',
        ),
        child: const Text('Collect'),
      );
    }
    if (status is Waiting) return null;
    if (_service.availableCopies(book.id) == 0) {
      return FilledButton.tonal(
        onPressed: () => _run(
          () => _service.reserve(memberId: _memberId, bookId: book.id),
          'Reserved "${book.title}"',
        ),
        child: const Text('Reserve'),
      );
    }
    return FilledButton(
      onPressed: () => _run(
        () => _service.borrow(memberId: _memberId, bookId: book.id),
        'Borrowed "${book.title}"',
      ),
      child: const Text('Borrow'),
    );
  }
}
