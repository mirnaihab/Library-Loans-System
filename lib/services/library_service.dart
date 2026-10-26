import 'dart:math';

import '../models/book.dart';
import '../models/fee.dart';
import '../models/loan.dart';
import '../models/member.dart';
import '../models/reservation.dart';

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
  static const holdPeriod = Duration(days: 3);

  final Map<String, Book> _books;
  final Map<String, Member> _members;
  final DateTime Function() _clock;
  final List<Loan> _loans = [];
  final List<Fee> _fees = [];
  final List<Reservation> _reservations = [];

  List<Book> get books => List.unmodifiable(_books.values);
  List<Member> get members => List.unmodifiable(_members.values);

  int availableCopies(String bookId) {
    _expireHolds();
    final book = _requireBook(bookId);
    final onLoan = _loans.where((l) => l.isActive && l.bookId == bookId).length;
    final onHold = _queueFor(bookId).where((r) => r.isOnHold).length;
    return book.totalCopies - onLoan - onHold;
  }

  List<Loan> activeLoansFor(String memberId) {
    _requireMember(memberId);
    return _loans.where((l) => l.isActive && l.memberId == memberId).toList();
  }

  /// Total of the member's unpaid late fees, in whole EGP.
  int outstandingFees(String memberId) {
    _requireMember(memberId);
    return _unpaidFeesFor(memberId).fold(0, (sum, f) => sum + f.amount);
  }

  /// Marks all of the member's unpaid late fees as paid.
  void payFees(String memberId) {
    if (outstandingFees(memberId) == 0) {
      throw const LoanException('No outstanding fees');
    }
    final today = _clock();
    for (final fee in _unpaidFeesFor(memberId)) {
      fee.paidOn = today;
    }
  }

  Iterable<Fee> _unpaidFeesFor(String memberId) =>
      _fees.where((f) => !f.isPaid && f.memberId == memberId);

  /// Adds the member to the back of the book's reservation queue.
  Reservation reserve({required String memberId, required String bookId}) {
    _expireHolds();
    _requireMember(memberId);
    _requireBook(bookId);
    if (_findActiveLoan(memberId, bookId) != null) {
      throw const LoanException('Member already has this book');
    }
    if (reservationStatus(memberId: memberId, bookId: bookId) != null) {
      throw const LoanException('Already reserved');
    }
    if (availableCopies(bookId) > 0) {
      throw const LoanException('Copies are available, borrow instead');
    }
    final reservation = Reservation(
      memberId: memberId,
      bookId: bookId,
      reservedOn: _clock(),
    );
    _reservations.add(reservation);
    return reservation;
  }

  /// Where the member's reservation for the book stands, or null if none.
  ReservationStatus? reservationStatus({
    required String memberId,
    required String bookId,
  }) {
    _expireHolds();
    final queue = _queueFor(bookId);
    final reservation = queue.where((r) => r.memberId == memberId).firstOrNull;
    if (reservation == null) return null;
    if (reservation.isOnHold) return OnHold(_lastDayOf(reservation));
    final waiting = queue.where((r) => !r.isOnHold).toList();
    return Waiting(waiting.indexOf(reservation) + 1);
  }

  /// Ends every hold whose last day has passed. Each copy goes on hold for
  /// the next waiting member from the day the previous hold expired, so a
  /// chain of expiries works out the same whenever it is looked at.
  void _expireHolds() {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    Reservation? expired() => _reservations
        .where((r) => r.isOnHold && _lastDayOf(r).isBefore(today))
        .firstOrNull;
    for (var hold = expired(); hold != null; hold = expired()) {
      _reservations.remove(hold);
      final lastDay = _lastDayOf(hold);
      final next = _queueFor(hold.bookId).where((r) => !r.isOnHold).firstOrNull;
      next?.heldOn = DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
    }
  }

  /// The last calendar day the member can collect their held copy.
  static DateTime _lastDayOf(Reservation hold) {
    final heldOn = hold.heldOn!;
    return DateTime(heldOn.year, heldOn.month, heldOn.day + holdPeriod.inDays);
  }

  /// The member's reservation for the book if a copy is on hold for them.
  Reservation? _holdFor(String memberId, String bookId) => _queueFor(
    bookId,
  ).where((r) => r.memberId == memberId && r.isOnHold).firstOrNull;

  /// The book's reservations, oldest first.
  List<Reservation> _queueFor(String bookId) =>
      _reservations.where((r) => r.bookId == bookId).toList();

  Loan borrow({required String memberId, required String bookId}) {
    _expireHolds();
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
    final hold = _holdFor(memberId, bookId);
    if (hold == null && availableCopies(bookId) == 0) {
      throw const LoanException('No copies available');
    }
    _reservations.remove(hold);
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
    _expireHolds();
    final loan = _findActiveLoan(memberId, bookId);
    if (loan == null) {
      throw const LoanException('Member does not have this book');
    }
    loan.returnedOn = _clock();
    final next = _queueFor(bookId).where((r) => !r.isOnHold).firstOrNull;
    next?.heldOn = loan.returnedOn;
    final daysLate = _calendarDaysBetween(loan.dueOn, loan.returnedOn!);
    if (daysLate > 0) {
      final amount = min(daysLate * lateFeePerDay, lateFeeCap);
      _fees.add(Fee(loan: loan, amount: amount));
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
