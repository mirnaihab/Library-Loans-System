class Reservation {
  Reservation({
    required this.memberId,
    required this.bookId,
    required this.reservedOn,
  });

  final String memberId;
  final String bookId;
  final DateTime reservedOn;
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
