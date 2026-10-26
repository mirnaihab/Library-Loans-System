import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_loans/data/sample_data.dart';
import 'package:library_loans/main.dart';
import 'package:library_loans/services/library_service.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    LibraryApp(
      service: LibraryService(books: sampleBooks, members: sampleMembers),
    ),
  );

  Finder buttonIn(String bookId, String label) => find.descendant(
    of: find.byKey(Key('book-$bookId')),
    matching: find.text(label),
  );

  Future<void> selectMember(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('memberPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows every book with its availability', (tester) async {
    await pumpApp(tester);

    expect(find.text('Clean Code'), findsOneWidget);
    expect(find.textContaining('2 of 2 available'), findsWidgets);
  });

  testWidgets('borrowing a book updates availability and shows Return', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(buttonIn('b2', 'Borrow'));
    await tester.pump();

    expect(find.textContaining('0 of 1 available'), findsOneWidget);
    expect(buttonIn('b2', 'Return'), findsOneWidget);
    expect(find.text('Borrowed "The Pragmatic Programmer"'), findsOneWidget);
  });

  Finder borrowCount(String text) => find.descendant(
    of: find.byKey(const Key('borrowCount')),
    matching: find.text(text),
  );

  testWidgets('shows how many books the member has borrowed', (tester) async {
    await pumpApp(tester);

    expect(borrowCount('0 of 3 books borrowed'), findsOneWidget);

    await tester.tap(buttonIn('b1', 'Borrow'));
    await tester.pump();

    expect(borrowCount('1 of 3 books borrowed'), findsOneWidget);
  });

  testWidgets('returning a book lowers the borrowed count', (tester) async {
    await pumpApp(tester);
    await tester.tap(buttonIn('b1', 'Borrow'));
    await tester.pump();

    await tester.tap(buttonIn('b1', 'Return'));
    await tester.pump();

    expect(borrowCount('0 of 3 books borrowed'), findsOneWidget);
  });

  testWidgets('switching member shows that member\'s count', (tester) async {
    await pumpApp(tester);
    await tester.tap(buttonIn('b1', 'Borrow'));
    await tester.pump();

    await selectMember(tester, 'Omar');

    expect(borrowCount('0 of 3 books borrowed'), findsOneWidget);

    await selectMember(tester, 'Sara');

    expect(borrowCount('1 of 3 books borrowed'), findsOneWidget);
  });

  testWidgets(
    'at the limit, Borrow stays enabled and shows the limit message',
    (tester) async {
      await pumpApp(tester);
      for (final bookId in ['b1', 'b2', 'b3']) {
        await tester.tap(buttonIn(bookId, 'Borrow'));
        await tester.pump();
      }

      final borrowButton = tester.widget<FilledButton>(
        find.ancestor(
          of: buttonIn('b4', 'Borrow'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(borrowButton.enabled, isTrue);

      await tester.tap(buttonIn('b4', 'Borrow'));
      await tester.pumpAndSettle(); // let the previous snackbar animate out

      expect(find.text('Borrowing limit reached (3 books)'), findsOneWidget);
      expect(borrowCount('3 of 3 books borrowed'), findsOneWidget);
    },
  );

  testWidgets('another member cannot borrow the last copy', (tester) async {
    await pumpApp(tester);
    await tester.tap(buttonIn('b2', 'Borrow'));
    await tester.pump();

    await selectMember(tester, 'Omar');
    await tester.tap(buttonIn('b2', 'Borrow'));
    await tester.pumpAndSettle(); // let the previous snackbar animate out

    expect(find.text('No copies available'), findsOneWidget);
  });
}
