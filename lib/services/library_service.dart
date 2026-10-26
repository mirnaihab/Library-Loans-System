import 'dart:math';

import '../models/book.dart';
import '../models/fee.dart';
import '../models/loan.dart';
import '../models/member.dart';

/// Thrown when a borrow or return is not allowed. [message] is shown to the user.
class LoanException implements Exception {
  const LoanException(this.message);

  final String message;

  @override
  String toString() => 'LoanException: $message';
}

/// All business rules for loans live here. The UI only calls this class.
///
/// Data is kept in memory. [clock] is injectable so tests can control "today".
class LibraryService {
  LibraryService({
    required List<Book> books,
    required List<Member> members,
    DateTime Function()? clock,
  }) : _books = {for (final b in books) b.id: b},
       _members = {for (final m in members) m.id: m},
       _clock = clock ?? DateTime.now;

  static const loanPeriod = Duration(days: 14);
  static const borrowingLimit = 3;
  static const lateFeePerDay = 5;
  static const lateFeeCap = 50;
  static const feeBlockThreshold = 20;

  final Map<String, Book> _books;
  final Map<String, Member> _members;
  final DateTime Function() _clock;
  final List<Loan> _loans = [];
  final List<Fee> _fees = [];

  List<Book> get books => List.unmodifiable(_books.values);
  List<Member> get members => List.unmodifiable(_members.values);

  int availableCopies(String bookId) {
    final book = _requireBook(bookId);
    final onLoan = _loans.where((l) => l.isActive && l.bookId == bookId).length;
    return book.totalCopies - onLoan;
  }

  List<Loan> activeLoansFor(String memberId) {
    _requireMember(memberId);
    return _loans.where((l) => l.isActive && l.memberId == memberId).toList();
  }

  /// Total of the member's unpaid late fees, in whole EGP.
  int outstandingFees(String memberId) {
    _requireMember(memberId);
    return _fees
        .where((f) => !f.isPaid && f.memberId == memberId)
        .fold(0, (sum, f) => sum + f.amount);
  }

  Loan borrow({required String memberId, required String bookId}) {
    _requireMember(memberId);
    _requireBook(bookId);
    if (_findActiveLoan(memberId, bookId) != null) {
      throw const LoanException('Member already has this book');
    }
    if (outstandingFees(memberId) > feeBlockThreshold) {
      throw const LoanException('Please pay outstanding fees first');
    }
    if (activeLoansFor(memberId).length >= borrowingLimit) {
      throw const LoanException(
        'Borrowing limit reached ($borrowingLimit books)',
      );
    }
    if (availableCopies(bookId) == 0) {
      throw const LoanException('No copies available');
    }
    final today = _clock();
    final loan = Loan(
      bookId: bookId,
      memberId: memberId,
      borrowedOn: today,
      dueOn: today.add(loanPeriod),
    );
    _loans.add(loan);
    return loan;
  }

  Loan returnBook({required String memberId, required String bookId}) {
    final loan = _findActiveLoan(memberId, bookId);
    if (loan == null) {
      throw const LoanException('Member does not have this book');
    }
    loan.returnedOn = _clock();
    final daysLate = _calendarDaysBetween(loan.dueOn, loan.returnedOn!);
    if (daysLate > 0) {
      final amount = min(daysLate * lateFeePerDay, lateFeeCap);
      _fees.add(Fee(memberId: memberId, loan: loan, amount: amount));
    }
    return loan;
  }

  /// Whole calendar days from [from] to [to], ignoring the time of day.
  static int _calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  Loan? _findActiveLoan(String memberId, String bookId) {
    for (final loan in _loans) {
      if (loan.isActive && loan.memberId == memberId && loan.bookId == bookId) {
        return loan;
      }
    }
    return null;
  }

  Book _requireBook(String id) =>
      _books[id] ?? (throw const LoanException('Book not found'));

  Member _requireMember(String id) =>
      _members[id] ?? (throw const LoanException('Member not found'));
}
