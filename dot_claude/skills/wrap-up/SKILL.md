---
name: wrap-up
description: Before closing a session, sweep it for loose ends and ask which to finish, export, or drop.
disable-model-invocation: true
---

The user is about to close this context. Anything that lives only in the conversation dies with it. Sweep the session for **loose ends**, show them, and let the user decide what happens to each before they go.

## 1. Sweep

Go back through the whole conversation, from the first message, and collect every loose end. Check each one against current state with tools (`git status`, the branch versus its remote, open PRs and their checks, running background tasks, containers you started) rather than trusting what an earlier message said. The sweep is done when every item below has been checked and either listed or ruled out.

- **Unfinished work**: anything you said you would do, offered to do, or started and did not finish. That includes questions you asked that never got an answer, and background tasks or agents still running.
- **Unshipped state**: uncommitted changes, local commits not pushed, worktrees, branches, draft PRs, and temporary resources (containers, dev servers, scratch files) that need finishing or tearing down.
- **Pending decisions**: choices you handed to the user that they have not made.
- **Stale claims**: anything you reported earlier that later turned out wrong or out of date and that you have not corrected in so many words.
- **Knowledge to export**: facts, preferences, or conventions learned here that the next session will need. For each one, name the right home: memory, the issue tracker, a repo doc, a PR description, or a handoff doc.

## 2. Report

Show one numbered list, grouped as **Finish now**, **Export**, and **Safe to drop**. Each item gets one line: what it is, where it stands (verified just now), and the action you propose, including the destination for exports. Take no action yet.

If the sweep found nothing, say so plainly and name what you checked.

## 3. Act

Ask which items to act on, with a multi-select question listing each item. Do the chosen ones. Commits, pushes, posting to external services, and deletions still need the user's explicit say-so, as they would outside this skill.

Finish by stating what you did, what is still open, and where each open item now lives, so nothing important remains only in this conversation.

## 4. Banner

The last thing you print is this tally, in a fenced code block so the columns hold. Nothing comes after it.

```
╭─ ✦ wrapped up ✦ ──────────────────────────╮
│  📋 Linear    2   SIL-468, SIL-469          │
│  🧠 Memory    1   pr-body-hook-file-order   │
│  📄 Repo docs 0                             │
│  🔀 PRs       0                             │
├─────────────────────────────────────────────┤
│  ⏳ Still open 5 → Linear ×4, PR #2604 ×1   │
│  🗑  Dropped   5                             │
╰─────────────────────────────────────────────╯
   nothing left only in this chat. bye! 👋
```

- The export rows count only what this wrap-up actually wrote in step 3: issues filed, memory files saved, repo docs changed, PR descriptions or comments updated. Name the issue tracker the project uses. Always show those four rows, zeros included; add a row only for another destination that received something, such as a handoff doc.
- List the IDs, file names or PR numbers after each count. If they do not fit, show the first two and `+N more`.
- **Still open** counts the open items from your closing statement, grouped by where each now lives. **Dropped** counts the Safe to drop items.
- Count an emoji as two columns when padding, so the right border lines up.
- If an item still lives only in this conversation, replace the sign-off line with `⚠ N item(s) still only in this chat` and name them above the banner.
