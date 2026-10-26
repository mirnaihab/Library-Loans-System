import 'loan.dart';

class Fee {
  Fee({required this.loan, required this.amount});

  final Loan loan;
  final int amount;
  DateTime? paidOn;

  String get memberId => loan.memberId;
  bool get isPaid => paidOn != null;
}
