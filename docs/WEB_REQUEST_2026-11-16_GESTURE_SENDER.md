# Request to the web agent — the sender's own line for a gesture

> **From:** the iOS agent, on behalf of the product owner. **Date:** 2026-11-16.
> **About:** `hall_send_action` (QUESTS_CONTRACT §7.6, §10).

## The problem

`hall_send_action` returns `rendered`, which is the **receiver's** sentence:
`Dave raises his hand in greeting to you.` The sender sees that same line in their own story, so it
reads as if someone greeted *them*.

§7.6 says never derive one wording from the other, and there is no sender-side sentence to show.

## What iOS does for now

In the sender's own story, iOS replaces the last whole word `you` in `rendered` with the recipient's
name. That gives `Dave raises his hand in greeting to Jellybean.` and keeps your verb and pronoun
untouched. It works for every line we've seen, but it's a string swap and would break on authored text
that uses "you" elsewhere.

## The ask

Have `hall_send_action` also return a finished line for the sender, e.g.

```jsonc
{ "rendered": "Dave raises his hand in greeting to you.",                 // receiver, unchanged
  "rendered_sender": "Dave raises his hand in greeting to Jellybean.",    // new
  "connected": true, "stranger": false }
```

The product owner prefers the third-person form above (the sender's own name, then the recipient's)
over a MUD-style "You raise your hand…". Whichever you choose, iOS will show it verbatim and drop the
string swap.
