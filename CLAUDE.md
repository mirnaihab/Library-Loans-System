# Library Loans (practice project)

Small Flutter app where library members borrow and return books.
Used to practice the agentic SDLC flow: spec → context → build → review.

## Commands
- Run tests: `flutter test`
- Static checks: `flutter analyze` (must show "No issues found")
- Format: `dart format lib test`
- Run the app: `flutter run -d chrome` (or `-d macos`)

## Structure
- `lib/models/`: plain data classes (`Book`, `Member`, `Loan`)
- `lib/services/library_service.dart`: **all business rules** (borrowing, returning, availability)
- `lib/screens/books_screen.dart`: UI only; calls the service and shows `LoanException.message` in a snackbar
- `lib/data/sample_data.dart`: demo books and members
- `test/library_service_test.dart`: unit tests for rules
- `test/books_screen_test.dart`: widget tests for the UI

## Rules
- Business rules go in `LibraryService`, never in widgets.
- Rule violations throw `LoanException` with a user-readable message.
- Time comes from the injected `clock`; never call `DateTime.now()` directly (keeps tests deterministic).
- Data is in memory only. No new packages without asking.
- Work test-first (red → green → refactor). One task per change; run `flutter test` and `flutter analyze` after each.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues on mirnaihab/Library-Loans-System (via `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
