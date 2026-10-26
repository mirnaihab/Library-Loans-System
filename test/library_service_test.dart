import 'package:flutter_test/flutter_test.dart';
import 'package:library_loans/models/book.dart';
import 'package:library_loans/models/member.dart';
import 'package:library_loans/models/reservation.dart';
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
        Member(id: 'm3', name: 'Lina'),
        Member(id: 'm4', name: 'Karim'),
      ],
      clock: () => today,
    );
  });

  Matcher throwsLoanException(String message) => throwsA(
    isA<LoanException>().having((e) => e.message, 'message', message),
  );

  /// Borrows on Jan 10 (due Jan 24), returns on [day], then resets the clock.
  void returnOn(DateTime day, {String memberId = 'm1', String bookId = 'b1'}) {
    service.borrow(memberId: memberId, bookId: bookId);
    today = day;
    service.returnBook(memberId: memberId, bookId: bookId);
    today = DateTime(2026, 1, 10);
  }

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
        throwsLoanException('No copies available'),
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
    void borrowUpToLimit(String memberId) {
      for (final bookId in ['b1', 'b2', 'b3']) {
        service.borrow(memberId: memberId, bookId: bookId);
      }
    }

    test('allows 3 active loans', () {
      borrowUpToLimit('m1');

      expect(service.activeLoansFor('m1'), hasLength(3));
    });

    test('rejects a 4th active loan', () {
      borrowUpToLimit('m1');

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b4'),
        throwsLoanException('Borrowing limit reached (3 books)'),
      );
    });

    test('a rejected borrow changes nothing', () {
      borrowUpToLimit('m1');

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b4'),
        throwsA(isA<LoanException>()),
      );
      expect(service.activeLoansFor('m1'), hasLength(3));
      expect(service.availableCopies('b4'), 1);
    });

    test('returning a book lets the member borrow again', () {
      borrowUpToLimit('m1');
      service.returnBook(memberId: 'm1', bookId: 'b2');

      final loan = service.borrow(memberId: 'm1', bookId: 'b4');

      expect(loan.isActive, isTrue);
      expect(service.activeLoansFor('m1'), hasLength(3));
    });

    test('counts overdue loans', () {
      borrowUpToLimit('m1');
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
      borrowUpToLimit('m1');

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b1'),
        throwsLoanException('Member already has this book'),
      );
    });

    test('is reported before "No copies available"', () {
      service.borrow(memberId: 'm2', bookId: 'b4');
      borrowUpToLimit('m1');

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

  group('late fees', () {
    test('a return 1 day late creates a 5 EGP fee', () {
      returnOn(DateTime(2026, 1, 25, 0, 1));

      expect(service.outstandingFees('m1'), 5);
    });

    test('a return on the due date creates no fee, whatever the time', () {
      returnOn(DateTime(2026, 1, 24, 23, 59));

      expect(service.outstandingFees('m1'), 0);
    });

    test('9 days late costs 45 EGP', () {
      returnOn(DateTime(2026, 2, 2));

      expect(service.outstandingFees('m1'), 45);
    });

    test('10 days late costs 50 EGP', () {
      returnOn(DateTime(2026, 2, 3));

      expect(service.outstandingFees('m1'), 50);
    });

    test('each fee is capped on its own', () {
      service.borrow(memberId: 'm1', bookId: 'b1');
      service.borrow(memberId: 'm1', bookId: 'b2');
      today = DateTime(2026, 1, 25); // 1 day late
      service.returnBook(memberId: 'm1', bookId: 'b2');
      today = DateTime(2026, 2, 23); // 30 days late
      service.returnBook(memberId: 'm1', bookId: 'b1');

      expect(service.outstandingFees('m1'), 55);
    });

    test('an overdue book that is not returned adds no fee', () {
      service.borrow(memberId: 'm1', bookId: 'b1');
      today = DateTime(2026, 2, 23);

      expect(service.outstandingFees('m1'), 0);
    });

    test('a single fee is capped at 50 EGP', () {
      returnOn(DateTime(2026, 2, 23)); // 30 days late

      expect(service.outstandingFees('m1'), 50);
    });

    test('outstanding fees fail for an unknown member', () {
      expect(
        () => service.outstandingFees('nobody'),
        throwsLoanException('Member not found'),
      );
    });
  });

  group('borrowing with outstanding fees', () {
    test('is blocked above 20 EGP', () {
      returnOn(DateTime(2026, 1, 29)); // 5 days late: 25 EGP

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b2'),
        throwsLoanException('Please pay outstanding fees first'),
      );
    });

    test('is allowed at exactly 20 EGP', () {
      returnOn(DateTime(2026, 1, 28)); // 4 days late: 20 EGP

      final loan = service.borrow(memberId: 'm1', bookId: 'b2');

      expect(loan.isActive, isTrue);
    });

    test('is reported after "Member already has this book"', () {
      service.borrow(memberId: 'm1', bookId: 'b2');
      returnOn(DateTime(2026, 1, 29)); // 25 EGP

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b2'),
        throwsLoanException('Member already has this book'),
      );
    });

    test('does not stop the member returning a book', () {
      service.borrow(memberId: 'm1', bookId: 'b2');
      returnOn(DateTime(2026, 1, 29)); // 25 EGP

      final loan = service.returnBook(memberId: 'm1', bookId: 'b2');

      expect(loan.isActive, isFalse);
    });

    test('is reported before "No copies available"', () {
      returnOn(DateTime(2026, 1, 29)); // 25 EGP
      service.borrow(memberId: 'm2', bookId: 'b2');

      expect(
        () => service.borrow(memberId: 'm1', bookId: 'b2'),
        throwsLoanException('Please pay outstanding fees first'),
      );
    });
  });

  group('payFees', () {
    test('clears outstanding fees so the member can borrow again', () {
      returnOn(DateTime(2026, 1, 29)); // 25 EGP

      service.payFees('m1');

      expect(service.outstandingFees('m1'), 0);
      expect(service.borrow(memberId: 'm1', bookId: 'b2').isActive, isTrue);
    });

    test('a late return after paying adds only the new fee', () {
      returnOn(DateTime(2026, 1, 29)); // 25 EGP
      service.payFees('m1');

      returnOn(DateTime(2026, 1, 25), bookId: 'b2'); // 5 EGP

      expect(service.outstandingFees('m1'), 5);
    });

    test('fails when nothing is owed', () {
      expect(
        () => service.payFees('m1'),
        throwsLoanException('No outstanding fees'),
      );
    });

    test('fails for an unknown member', () {
      expect(
        () => service.payFees('nobody'),
        throwsLoanException('Member not found'),
      );
    });
  });

  group('reserve', () {
    // b2 has 1 copy; Lina has it, so it has 0 available copies.
    setUp(() => service.borrow(memberId: 'm3', bookId: 'b2'));

    ReservationStatus? statusOf(String memberId, {String bookId = 'b2'}) =>
        service.reservationStatus(memberId: memberId, bookId: bookId);

    test('joins the reservation queue in order', () {
      service.reserve(memberId: 'm1', bookId: 'b2');
      service.reserve(memberId: 'm2', bookId: 'b2');

      expect(statusOf('m1'), const Waiting(1));
      expect(statusOf('m2'), const Waiting(2));
    });

    test('fails when copies are available', () {
      expect(
        () => service.reserve(memberId: 'm1', bookId: 'b1'),
        throwsLoanException('Copies are available, borrow instead'),
      );
    });

    test('fails for a book the member has on loan', () {
      expect(
        () => service.reserve(memberId: 'm3', bookId: 'b2'),
        throwsLoanException('Member already has this book'),
      );
    });

    test('fails when the member has already reserved the book', () {
      service.reserve(memberId: 'm1', bookId: 'b2');

      expect(
        () => service.reserve(memberId: 'm1', bookId: 'b2'),
        throwsLoanException('Already reserved'),
      );
    });

    test('is allowed at the borrowing limit', () {
      for (final bookId in ['b1', 'b3', 'b4']) {
        service.borrow(memberId: 'm1', bookId: bookId);
      }

      service.reserve(memberId: 'm1', bookId: 'b2');

      expect(statusOf('m1'), const Waiting(1));
    });

    test('is allowed while owing more than 20 EGP', () {
      returnOn(DateTime(2026, 1, 29)); // 25 EGP

      service.reserve(memberId: 'm1', bookId: 'b2');

      expect(statusOf('m1'), const Waiting(1));
    });

    test('does not count toward the borrowing limit', () {
      service.reserve(memberId: 'm1', bookId: 'b2');

      for (final bookId in ['b1', 'b3', 'b4']) {
        service.borrow(memberId: 'm1', bookId: bookId);
      }

      expect(service.activeLoansFor('m1'), hasLength(3));
    });

    test('fails for an unknown member or book', () {
      expect(
        () => service.reserve(memberId: 'nobody', bookId: 'b2'),
        throwsLoanException('Member not found'),
      );
      expect(
        () => service.reserve(memberId: 'm1', bookId: 'nothing'),
        throwsLoanException('Book not found'),
      );
    });
  });

  group('holds', () {
    // Lina borrowed b2 (1 copy) on Jan 1; today is Jan 10.
    setUp(() {
      today = DateTime(2026, 1, 1);
      service.borrow(memberId: 'm3', bookId: 'b2');
      today = DateTime(2026, 1, 10);
    });

    ReservationStatus? statusOf(String memberId) =>
        service.reservationStatus(memberId: memberId, bookId: 'b2');

    void linaReturnsB2() => service.returnBook(memberId: 'm3', bookId: 'b2');

    test('a returned copy goes on hold for the first in the queue', () {
      service.reserve(memberId: 'm1', bookId: 'b2');
      service.reserve(memberId: 'm2', bookId: 'b2');

      linaReturnsB2();

      expect(statusOf('m1'), OnHold(DateTime(2026, 1, 13)));
      expect(statusOf('m2'), const Waiting(1));
      expect(service.availableCopies('b2'), 0);
    });

    test('another member cannot borrow a held copy', () {
      service.reserve(memberId: 'm1', bookId: 'b2');
      service.reserve(memberId: 'm2', bookId: 'b2');
      linaReturnsB2();

      expect(
        () => service.borrow(memberId: 'm2', bookId: 'b2'),
        throwsLoanException('No copies available'),
      );
    });

    test('the holder collects the copy by borrowing it', () {
      service.reserve(memberId: 'm1', bookId: 'b2');
      linaReturnsB2();

      final loan = service.borrow(memberId: 'm1', bookId: 'b2');

      expect(loan.isActive, isTrue);
      expect(statusOf('m1'), isNull);
      expect(service.availableCopies('b2'), 0);
    });

    test(
      'a holder at the borrowing limit cannot collect, and keeps the hold',
      () {
        for (final bookId in ['b1', 'b3', 'b4']) {
          service.borrow(memberId: 'm1', bookId: bookId);
        }
        service.reserve(memberId: 'm1', bookId: 'b2');
        linaReturnsB2();

        expect(
          () => service.borrow(memberId: 'm1', bookId: 'b2'),
          throwsLoanException('Borrowing limit reached (3 books)'),
        );
        expect(statusOf('m1'), OnHold(DateTime(2026, 1, 13)));
      },
    );

    test('each returned copy goes on hold for the next in the queue', () {
      // Both copies of b1 are out with Lina and Karim.
      service.borrow(memberId: 'm3', bookId: 'b1');
      service.borrow(memberId: 'm4', bookId: 'b1');
      service.reserve(memberId: 'm1', bookId: 'b1');
      service.reserve(memberId: 'm2', bookId: 'b1');

      service.returnBook(memberId: 'm3', bookId: 'b1');
      service.returnBook(memberId: 'm4', bookId: 'b1');

      final lastDay = OnHold(DateTime(2026, 1, 13));
      expect(service.reservationStatus(memberId: 'm1', bookId: 'b1'), lastDay);
      expect(service.reservationStatus(memberId: 'm2', bookId: 'b1'), lastDay);
      expect(service.availableCopies('b1'), 0);
    });
  });
}
