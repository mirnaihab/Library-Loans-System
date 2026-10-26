# Practice guide: one story through the whole agentic SDLC

Goal: take **Story 1 (Borrowing limit)** from `STORIES.md` through every phase,
using the real tools. Then repeat with Stories 2 and 3 using less help each time.

```
① SPEC  →  ② CONTEXT  →  ③ BUILD  →  ④ REVIEW  →  PR
```

Keep a file called `NOTES.md` open the whole time. After every stage, write down:
what the tool did, what surprised you, what went wrong, roughly how many tokens it used.
That file becomes your report to your manager (and your "gaps" log later).

> Before installing anything: this is a toy project, so it's safe. On real PwC code,
> check which tools and AI providers are approved before sending code to them.

---

## Stage 0: Get to know the project (15 min)

Open the folder in **VS Code** (install the "Flutter" and "Claude Code" extensions).

```sh
cd ~/development/library-loans
flutter test               # 10 tests should pass
flutter run -d chrome      # try borrowing and returning books, switch members
claude                     # open Claude Code here (VS Code terminal: Ctrl+`)
```

Read `CLAUDE.md`. This is the **context file**: the agent reads it at the start of
every session. Notice how short it is: commands, structure, rules. Nothing more.

---

## Stage 1: Install the tools (30–45 min)

Run these in a normal terminal (not inside Claude).

```sh
# ① Spec: OpenSpec
npm install -g @fission-ai/openspec@latest
cd ~/development/library-loans && openspec init     # choose Claude Code

# ① + ③ Matt Pocock's skills (grill-me, tdd, diagnose, ...)
npx skills add mattpocock/skills

# ② Context: Graphify (needs uv, a Python tool installer)
brew install uv
uv tool install graphifyy          # two y's
graphify install                   # registers /graphify with Claude Code

# ③ Build: Ahmed Nagdy's delegate skills (Claude delegating to Claude)
npx skills add amElnagdy/delegate-skills --skill delegate-setup --agent claude-code
npx skills add amElnagdy/delegate-skills --skill claude-delegate --agent claude-code

# ④ Review: Alibaba Open Code Review
npm install -g @alibaba-group/open-code-review
ocr config provider                # pick Anthropic, paste an API key if you have one
```

Restart Claude Code after installing so it picks up the new skills.
If a command fails, check that tool's README: these projects change fast.

---

## Stage 2: ① SPEC (45 min)

Inside Claude Code:

1. **Grill:** `/grill-me` then paste Story 1 from `STORIES.md`.
   Answer its questions. Notice the ones you hadn't thought about
   (Does the limit apply per member or per book? What if the limit changes later?
   Should the Borrow button be disabled at 3, or show an error when tapped?).
2. **Propose:** `/opsx:propose add-borrowing-limit`
3. **Read what it created** under `openspec/changes/add-borrowing-limit/`:
   `proposal.md` (why), `specs/` (what, as a delta), `design.md` (how), `tasks.md` (steps).
4. **Act like the human gate.** Check each AC from the story is covered by the spec.
   If something's missing, tell the agent to fix the spec, not the code.

✅ Checkpoint: you approved a spec where every AC is traceable.

---

## Stage 3: ② CONTEXT (20 min)

1. In Claude Code: `/graphify .`
2. Open `graphify-out/graph.html` in your browser and click around.
3. Ask Claude: *"Using the graph, where should the borrowing limit rule live, and what calls it?"*
   It should point to `LibraryService.borrow` without reading every file.

**Check one thing:** does the graph contain your Dart classes and methods
(`LibraryService`, `borrow`, `BooksScreen`)? If Graphify doesn't parse Dart well,
write that in `NOTES.md`. That's a real finding: if your company's repos are Flutter,
the team needs to know before relying on this tool.

✅ Checkpoint: you can explain what's in `graphify-out/` and why teams commit it to git.

---

## Stage 4: ③ BUILD (1 hour)

```sh
git checkout -b feature/borrowing-limit
```

1. In Claude Code: `/opsx:apply`. Tell it: *"Use /tdd: for each task, write the failing test first,
   show me it fails, then the smallest code to pass."*
2. **After every task:** look at the diff (VS Code Source Control tab, or `git diff`) and run
   `flutter test` and `flutter analyze` yourself. Don't let it do all tasks in one go.
3. **Try delegation once:** run `$delegate-setup`, then ask Claude to use `$claude-delegate`
   for one mechanical task (e.g. *"add the 'X of 3 books borrowed' label to the screen"*).
   Notice: the sub-agent returns a diff and a report, **you** review and commit.
4. Run the app (`flutter run -d chrome`) and test the story by hand, like a real user.
5. When everything is green: `/opsx:archive` (moves the change into the permanent specs).

Watch for the agent "cheating": editing a test so it passes instead of fixing the code,
or putting the rule in the widget instead of `LibraryService` (check `CLAUDE.md` rules).

✅ Checkpoint: all 4 ACs have tests, all tests pass, analyze is clean, you've read every line.

---

## Stage 5: ④ REVIEW (30–45 min)

1. **Your own review first** (10 min). Write down what you'd flag.
2. **AI review:** `ocr review --from main --to feature/borrowing-limit`
3. **Debate review (optional, harder setup):** install `npx skills add amElnagdy/review-skills`.
   It needs two reviewer "lanes" from `$delegate-setup` (ideally two different models),
   then run `$debate-review --local`. Compare one reviewer vs two arguing reviewers.
4. Compare: what did you catch that the tools missed, and vice versa? Write it in `NOTES.md`.
5. Fix the real findings (test-first), ignore the noise, and note which was which.

✅ Checkpoint: a short table in `NOTES.md`: finding, found by (me / OCR / debate), real or noise.

---

## Stage 6: "PR" and reflection (20 min)

```sh
git add -A && git commit -m "Add borrowing limit"
git checkout main && git merge feature/borrowing-limit
```

Write the PR description in `NOTES.md` as if for a reviewer:
what changed and why, evidence (test output, a screenshot), risks.

Then answer for yourself:
- Which phase saved the most time? Which cost the most tokens?
- What would you change in this flow? (← this is what step 4 of your manager's plan asks for)

---

## Then repeat

- **Story 2 (late fees):** do it with less help from this guide. Lots of edge cases
  (exactly on the due date? the cap?), which is perfect for TDD.
- **Story 3 (reservations):** deliberately vague. Spend extra time in `/grill-me`.
  This is where spec-first pays off most.

By the end you've used: OpenSpec, grill-me, Graphify, TDD, delegate skills,
Open Code Review and (optionally) debate review, on one codebase, end to end.
