import 'loan.dart';

class Fee {
  Fee({required this.memberId, required this.loan, required this.amount});

  final String memberId;
  final Loan loan;
  final int amount;
  DateTime? paidOn;

  bool get isPaid => paidOn != null;
}
