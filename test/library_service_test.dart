import 'package:flutter_test/flutter_test.dart';
import 'package:library_loans/models/book.dart';
import 'package:library_loans/models/member.dart';
import 'package:library_loans/services/library_service.dart';

void main() {
  late DateTime today;
  late LibraryService service;

  setUp(() {
    today = DateTime(2026, 1, 10);
    service = LibraryService(
      books: const [
        Book(id: 'b1', title: 'Clean Code', author: 'Martin', totalCopies: 2),
        Book(id: 'b2', title: 'Refactoring', author: 'Fowler', totalCopies: 1),
        Book(id: 'b3', title: 'DDD', author: 'Evans', totalCopies: 1),
        Book(id: 'b4', title: 'TDD', author: 'Beck', totalCopies: 1),
      ],
      members: const [
        Member(id: 'm1', name: 'Sara'),
        Member(id: 'm2', name: 'Omar'),
      ],
      clock: () => today,
    );
  });

  group('borrow', () {
    test('creates a loan due in 14 days', () {
      final loan = service.borrow(memberId: 'm1', bookId: 'b1');

      expect(loan.borrowedOn, DateTime(2026, 1, 10));
      expect(loan.dueOn, DateTime(2026, 1, 24));
      expect(loan.isActive, isTrue);
    });

    test('reduces available copies', () {
      service.borrow(memberId: 'm1', bookId: 'b1');

      expect(service.availableCopies('b1'), 1);
    });

    test('fails when no copies are left', () {
      service.borrow(memberId: 'm1', bookId: 'b2');

      expect(
        () => service.borrow(memberId: 'm2', bookId: 'b2'),
        throwsA(
          isA<LoanException>().having(
            (e) => e.message,
            'message',
            'No copies available',
          ),
        ),
      );
    });

    test('fails when the member already has the book', () {
      service.borrow(memberId: 'm1', bookId: 'b1');

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b1'),
        throwsA(isA<LoanException>()),
      );
    });

    test('fails for an unknown member or book', () {
      expect(
        () => service.borrow(memberId: 'nobody', bookId: 'b1'),
        throwsA(isA<LoanException>()),
      );
      expect(
        () => service.borrow(memberId: 'm1', bookId: 'nothing'),
        throwsA(isA<LoanException>()),
      );
    });
  });

  group('borrowing limit', () {
    void borrowThree(String memberId) {
      for (final bookId in ['b1', 'b2', 'b3']) {
        service.borrow(memberId: memberId, bookId: bookId);
      }
    }

    Matcher throwsLoanException(String message) => throwsA(
      isA<LoanException>().having((e) => e.message, 'message', message),
    );

    test('allows 3 active loans', () {
      borrowThree('m1');

      expect(service.activeLoansFor('m1'), hasLength(3));
    });

    test('rejects a 4th active loan', () {
      borrowThree('m1');

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b4'),
        throwsLoanException('Borrowing limit reached (3 books)'),
      );
    });

    test('a rejected borrow changes nothing', () {
      borrowThree('m1');

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b4'),
        throwsA(isA<LoanException>()),
      );
      expect(service.activeLoansFor('m1'), hasLength(3));
      expect(service.availableCopies('b4'), 1);
    });

    test('returning a book lets the member borrow again', () {
      borrowThree('m1');
      service.returnBook(memberId: 'm1', bookId: 'b2');

      final loan = service.borrow(memberId: 'm1', bookId: 'b4');

      expect(loan.isActive, isTrue);
      expect(service.activeLoansFor('m1'), hasLength(3));
    });

    test('counts overdue loans', () {
      borrowThree('m1');
      today = DateTime(2026, 3, 1);

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b4'),
        throwsLoanException('Borrowing limit reached (3 books)'),
      );
    });

    test('applies to each member separately', () {
      service.borrow(memberId: 'm1', bookId: 'b2');
      service.borrow(memberId: 'm1', bookId: 'b3');
      service.borrow(memberId: 'm1', bookId: 'b4');

      final loan = service.borrow(memberId: 'm2', bookId: 'b1');

      expect(loan.memberId, 'm2');
    });

    test('is reported after "Member already has this book"', () {
      borrowThree('m1');

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b1'),
        throwsLoanException('Member already has this book'),
      );
    });

    test('is reported before "No copies available"', () {
      service.borrow(memberId: 'm2', bookId: 'b4');
      borrowThree('m1');

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b4'),
        throwsLoanException('Borrowing limit reached (3 books)'),
      );
    });
  });

  group('returnBook', () {
    test('ends the loan and frees the copy', () {
      service.borrow(memberId: 'm1', bookId: 'b2');
      today = DateTime(2026, 1, 15);

      final loan = service.returnBook(memberId: 'm1', bookId: 'b2');

      expect(loan.returnedOn, DateTime(2026, 1, 15));
      expect(service.availableCopies('b2'), 1);
      expect(service.activeLoansFor('m1'), isEmpty);
    });

    test('fails when the member does not have the book', () {
      expect(
        () => service.returnBook(memberId: 'm1', bookId: 'b1'),
        throwsA(isA<LoanException>()),
      );
    });
  });
}
