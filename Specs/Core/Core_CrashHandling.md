# Crash handling

RedMonitor writes local minidumps for fatal viewer failures. The producer SDK stays independent of the viewer and never installs a process handler.

## Installation and fault handling

- On an ordinary launch, prepare the viewer's application-owned crash store under the Windows Local AppData known folder at "RedMonitor/Crashes". Refuse non-local and reparse destinations. Install before creating windows or starting workers. A failed preparation returns its error and stops startup.
- The top-level Win32 filter, unhandled worker faults, termination, invalid parameters, pure virtual calls and SIGABRT use one report writer. Prepare the completion event, stack reserve and system DbgHelp entry point while startup is healthy. The writer uses fixed storage, creates at most one dump per process failure, and does no application recovery or UI on the fault path. The process exits with the fatal status.
- A complete flushed "RedMonitor-report-*.dmp" is followed by an atomically published UTF-16 leaf name in "pending.txt". A failed report leaves any earlier pending notice intact. Reports and notices stay local.
- Help, distribution contract checks, hidden self-tests and performance captures skip the user crash store. Test builds admit the isolated "--crash-probe" and "--crash-probe-worker" commands through the owned harness. Production builds reject both commands.

## Restart

The next ordinary launch of the viewer claims the pending notice after its main window starts. It shows a localized prompt with the report path once. On a healthy interactive start, retain the newest ten RedMonitor reports by write time and preserve legacy reports and unrelated files. RedMonitor currently creates no sidecars.

## Validation

Run [the unattended regression](../Testing/Testing_Validation.md) with test-enabled binaries. The crash cases check both child exit statuses, one minidump with the MDMP signature and its matching marker per fault, overlapping worker faults, and marker preservation during --runtime-contract. The console store case covers zero, ten and eleven reports, legacy evidence, and the one-time notice claim. The visible prompt is a separate interactive validation.
