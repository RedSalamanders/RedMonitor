- Every local skill description now says what the skill does and then when to use it ("Use when ..."), the form
  the shared `RedHome` skills already use, because an agent picks a skill from its description alone (`RedHome`
  convergence step CV-2-13). All six skills gain the clause, taken from each skill's own body; only their
  front-matter descriptions change. `validate.ps1` and the tooling tests pass; no build, test or product input
  changes.
