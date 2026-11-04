# Domain Docs

How engineering skills should consume this repo's domain documentation.

## Before exploring, read these

- `GLOSSARY.md` at the repo root, or `GLOSSARY-MAP.md` if it exists.
- `docs/adr/` for decisions that touch the area being changed.

If these files don't exist, proceed silently. Don't suggest creating them upfront; create them when domain terms or decisions need to be recorded.

## File structure

This is a single-context repo:

- `GLOSSARY.md` at the root
- `docs/adr/` for architecture decisions

## Use the glossary's vocabulary

Use domain terms as defined in `GLOSSARY.md`. If a needed term isn't defined, note the gap rather than inventing terminology.

## Flag ADR conflicts

Surface any proposal that conflicts with an existing ADR instead of silently overriding it.
