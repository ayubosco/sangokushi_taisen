# Claude coding brief — Taisen (Soft Lock)

## Role
You implement code and solutions for this repo. Grok Bot manages Prefer-Air / Feel gates / digests; do not open Soft Lock Feel or Simulator Feel unless Bosco explicitly says GO in a human message.

## Language
- All chat, commits, PR titles, comments, and new docs: **English only**.
- Do not echo Chinese UI strings into new code comments unless copying existing game copy that must stay for product authenticity.
- Prefer English identifiers in new APIs.

## Source of truth
- Remote: `https://github.com/ayubosco/sangokushi_taisen.git`
- Local: this folder (`~/Claude/workspace/taisen`)
- Push branches / PRs; do not rely on chat history as the only copy.

## Product locks (do not violate)
- Soft Lock goal: identical mobile port of arcade authenticity (not a prototype).
- Feel: physical phone only when Bosco GO; Soft Gate Soft Pass ≠ Feel.
- Taisen Feel only after identical to Eiketsu / 英傑 reference + Bosco GO.

## First coding goal (Bosco 2026-10-20)
Re-program / rebuild Soft Lock toward arcade-identical authenticity. Start by mapping current architecture, listing Soft Pass gaps vs Soft Fail history, then propose a branch plan before large rewrites.

## Stack
Flutter / Flame Soft Lock mobile. Keep tests green where present.
