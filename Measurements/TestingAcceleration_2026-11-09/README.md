# Pinned SDK application pilot

The [native record](pinned-sdk-application.json) identifies the actual frozen working-tree source,
complete SDK input key, immutable manifest, compiler/storage identities, build artifacts and separate
runtime/package results. This is x64 Release application evidence, not complete product qualification.

- The unchanged API-4 f2e328a0 source was independently restored for input acquisition. Its reader checkout
  had no built DxUi.lib before/after; the application had no source dependency checkout. MSBuild linked
  the immutable SDK payload with its reader held and recorded `PinnedReleaseSdkV1` in the build receipt.
- All 14 actual MSBuild admission controls passed, including per-file CRT/language/ASan/annotation
  rejection and refusal of the same settings after its reader closed.
- The application built with zero warnings/errors. All seven console scenarios passed, including the
  real owned ETW roundtrip and production metadata. Packaging reopened the same SDK key/manifest for
  its complete notices, verified extracted bytes and passed the extracted runtime contract.
- The SDK warm build took about 61 seconds in one diagnostic. A controlled warm source comparison is
  pending; local source remains the default. No overall acceleration target is claimed.

The first application build refused 28 duplicate Windows macro warnings; its log is preserved locally.
Conditional feature definitions removed the warnings without suppression. The first policy wrapper also
preserved an expected negative native exit after its 14 controls passed; completion status was corrected
and all controls reran. Original records remain retained.

The source identity predates this evidence-only addition. Source fallback Debug/ASan/all-architecture
checks, native ARM64 SDK/application acceptance, UI/device/performance coverage and hosted authenticated
SDK transport remain separate. The organization implementation plan stays WIP.
