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

  testWidgets('another member cannot borrow the last copy', (tester) async {
    await pumpApp(tester);
    await tester.tap(buttonIn('b2', 'Borrow'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('memberPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omar').last);
    await tester.pumpAndSettle();
    await tester.tap(buttonIn('b2', 'Borrow'));
    await tester.pumpAndSettle(); // let the previous snackbar animate out

    expect(find.text('No copies available'), findsOneWidget);
  });
}
