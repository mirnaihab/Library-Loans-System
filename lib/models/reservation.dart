class Reservation {
  Reservation({
    required this.memberId,
    required this.bookId,
    required this.reservedOn,
  });

  final String memberId;
  final String bookId;
  final DateTime reservedOn;

  /// When a returned copy went on hold for this member; null while waiting.
  DateTime? heldOn;

  bool get isOnHold => heldOn != null;
}

/// Where a member's reservation for a book stands.
sealed class ReservationStatus {
  const ReservationStatus();
}

/// Waiting in the reservation queue; [position] 1 is next in line.
final class Waiting extends ReservationStatus {
  const Waiting(this.position);

  final int position;

  @override
  bool operator ==(Object other) =>
      other is Waiting && other.position == position;

  @override
  int get hashCode => position.hashCode;

  @override
  String toString() => 'Waiting($position)';
}

/// A copy is on hold for the member; they can collect it through [lastDay].
final class OnHold extends ReservationStatus {
  const OnHold(this.lastDay);

  final DateTime lastDay;

  @override
  bool operator ==(Object other) => other is OnHold && other.lastDay == lastDay;

  @override
  int get hashCode => lastDay.hashCode;

  @override
  String toString() => 'OnHold($lastDay)';
}
