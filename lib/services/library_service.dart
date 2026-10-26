import '../models/book.dart';
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

  final Map<String, Book> _books;
  final Map<String, Member> _members;
  final DateTime Function() _clock;
  final List<Loan> _loans = [];

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

  Loan borrow({required String memberId, required String bookId}) {
    _requireMember(memberId);
    _requireBook(bookId);
    if (_findActiveLoan(memberId, bookId) != null) {
      throw const LoanException('Member already has this book');
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
    return loan;
  }

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
