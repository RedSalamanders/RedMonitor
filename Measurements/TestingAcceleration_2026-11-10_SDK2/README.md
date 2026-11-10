# I61 qualified SDK reader: local application evidence

The actual x64 Release test-enabled build, all seven native/ETW scenarios,
test-disabled production build, SDK notice reopening, portable packaging and 14
clean-extraction/installation controls passed with `PinnedQualifiedReleaseSdkV2`.
Both builds reported zero warnings and errors. The dependency pin remains
`f2e328a0a26a18ca66bf4b2aea77bf010c9515e1`, API 4.

This run used the real independently retained SDK, ABI reference, SDK qualification
receipt and immutable byte store. Only the private hosted-origin resolver was a
controlled fixture in the parent process. It therefore proves actual application
SDK consumption, runtime and packaging against those bytes; it does **not** prove
live GitHub producer authentication or hosted SDK-hit acceptance. The fixture's
run ID 6111102 is a local SDK producer identity, not a claimed GitHub run.

The executed application snapshot and original dependency/archive/package
identities are recorded in [evidence.json](evidence.json). Its controller was
`64364b1e375b76c248b556fa70e5777fefa58ba3`; later documentation and the
case-preserving Linux guard repair are not retroactively included in that run.
The complete sequence took 152,121 ms. This is a component observation with no
paired baseline and establishes no organization-wide acceleration target.

Original evidence remains under this worktree's `.build/`:

- `i61-qualified-sdk2-application-owned-paths.log`
- `sdk-v2-reader-controls/83e16d4744fb44c1a1e3f304007c282f/`
- `installation-tests/fdb1dcbc6dee433abd1c46d49f72dac5/`

Earlier attempts are retained separately: the first correctly used Source after
a different MSBuild selection; subsequent native builds exposed child compiler
environment/default-search-path incompatibilities in the new guard. They were
refused and are not relabeled successful. The guard now preserves default system
search order, admits existing owned additions and rejects foreign/reordered
paths. Explicit native host selection has 43 source/build-console controls.

Matching hosted engines/callers, live qualified
producer attempts, both native hosted architectures and overall I61 closeout
remain independently required. No gate or dependency pin is removed here.

## Source-profile closeout

The subsequent final-controller Source PrePush passed complete validation, format
and tooling, x64 Debug/Release/ASan native tests with live ETW and the actual ASan
detector, all six zero-warning/error builds, portable packaging and 14 installation
controls. Its exact execution snapshots are in [source-profile-checks.json](source-profile-checks.json).
Three additional controls executed the real package command and refused an unknown
recipe and either SDK recipe without its required descriptor, then restored the
original build receipt byte for byte. These evidence-only additions follow those
executions; they do not rewrite the original snapshot identity.

