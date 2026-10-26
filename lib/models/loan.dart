class Loan {
  Loan({
    required this.bookId,
    required this.memberId,
    required this.borrowedOn,
    required this.dueOn,
  });

  final String bookId;
  final String memberId;
  final DateTime borrowedOn;
  final DateTime dueOn;
  DateTime? returnedOn;

  bool get isActive => returnedOn == null;
}
