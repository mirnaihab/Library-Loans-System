# Practice user stories

Implement these one at a time, in order. Each one goes through the full flow in PRACTICE.md.

## Story 1: Borrowing limit
As a librarian, I want to limit how many books a member can have at once,
so that books stay available for everyone.

**Acceptance criteria**
1. A member can have at most 3 books on loan at the same time.
2. Borrowing a 4th book is rejected with the message "Borrowing limit reached (3 books)".
3. Returning a book frees a slot, so the member can borrow again.
4. The screen shows how many books the selected member has, e.g. "2 of 3 books borrowed".

## Story 2: Late fees
As a librarian, I want late returns to create a fee, so that members return books on time.

**Acceptance criteria**
1. Returning a book after its due date creates a fee of 5 EGP per day late.
2. A single fee is capped at 50 EGP.
3. Returning on or before the due date creates no fee.
4. A member who owes more than 20 EGP cannot borrow, with the message "Please pay outstanding fees first".
5. The screen shows the selected member's outstanding fees, and a librarian can mark them as paid.

## Story 3: Reservations
As a member, I want to reserve a book that is currently unavailable,
so that I get it when it comes back.

**Acceptance criteria**
1. A member can reserve a book that has no available copies.
2. When a copy is returned, it is held for the first member in the queue.
3. Other members cannot borrow a held copy.
4. Holds expire if not collected.

(Story 3 is deliberately vague. How long does a hold last? Can you reserve a book you
already have? Does a reservation count towards the 3-book limit? What does the UI show?
Let /grill-me find these questions before any code is written.)
