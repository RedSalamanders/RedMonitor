- Agent guidance now matches the other RedSalamanders repositories (`RedHome` convergence step CV-6-02).
  `.github/copilot-instructions.md` is the identical pointer to `AGENTS.md` that every repository uses. `AGENTS.md`
  has `## Engineering` and `## Skills` headings, with the shared-skill pointer directly under `## Skills`. It gains
  the shared drive-root, interactive desktop, scoped-testing and Changes sections, and Unified CI takes the shared
  text. The shared native build policy waits for the build-profile step, because RedMonitor still builds with
  `/W4 /WX`. The common `.gitignore` block ignores `.claude/settings.local.json` and `.claude/scheduled_tasks.lock`,
  and `capabilities.json` says `supported` instead of `implemented`. Nothing compiles differently.
