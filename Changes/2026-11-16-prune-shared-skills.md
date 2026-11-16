- Consolidated the shared `spec-workflow` agent skill into the organization `RedHome` repository, retaining the six
  RedMonitor-specific skills under `.agents/skills/` and validating with `validate.ps1` and `Tools/Test-Changelog.ps1`
  (documentation/tooling only; native qualification unchanged).
  Shared-skill discovery names `../RedHome/AGENTS.md`, the package directory, and the clone URL while preserving
  local product authority.
  Guidance fixtures also recognize Windows error 1314 as unavailable symbolic-link privilege and report the
  documented capability skip; other I/O errors still fail.
