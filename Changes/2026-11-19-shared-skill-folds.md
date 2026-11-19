- Retired three repository-local agent skills now folded into shared skills in `RedHome` (convergence CV-2-12):
  `build-redmonitor` into `native-build`, `file-safety` into `file-io-safety`, and `test-harness` into
  `test-evidence`. Every rule and code line of the three is in the shared skills, with RedMonitor's commands,
  budgets and rules in each one's `references/repository-facts.md`. Claude Code (the `redhome` plugin), Codex, and
  Copilot list the shared skills from this repository. `AGENTS.md` points at them. No build, test or product input
  changes.
