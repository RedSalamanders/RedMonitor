- Added a resource-string gate, `Tests/Tooling.Tests.ResourceStrings.ps1`, run by the tooling tests without native
  compilation (RedHome register H-08, CV-6-08). It fails on a bare `{}` or unindexed `{:...}`, a printf token, a
  placeholder index gap, a string id missing from `src/resource.h`, an `IDS_` id the viewer source uses without a
  base string, and a satellite string whose placeholders differ from the base. Today's 51 base strings and four
  satellites pass; no string changes.
