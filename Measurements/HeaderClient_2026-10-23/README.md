# Single-header delivery qualification — 2026-10-23

The reviewed [validation receipt](validation.json) records the final PrePush source identity,
all six successful build receipts and rechecked viewer/artifact hashes, three x64 native runtime
receipts with real ETW, actual ASan detection, the production Release ZIP and 14 contained installer
controls. Native model/file/settings/client/metadata tests passed in each applicable profile.
The production code/public bytes remain at commit 9ebea6577fe9a5ced7647283c918f51f67d666fd;
the source identity also includes the later contracts, capabilities and delivery-plan updates.
Measurements are excluded from the source digest, so adding this reviewed report does not invalidate it.

All four consumers pin the same public header/license bytes. RedPrism and RedTilde passed their six
builds, three x64 Full profiles, real application probes and portable packages. RedXe additionally
passed [all six hosted native profiles](https://github.com/RedSalamanders/RedXe/actions/runs/39954330299),
including ARM64, with its independently reviewed archive hashes retained in its own repository.
RedSalamander's consumer WIP records exact completed/failed attempts and the owner's instruction to
keep its independent Release instance open and defer x64 Release validation and packaging.

This is console/component and contained installer qualification. Native ARM64 standalone execution,
viewer UI/WARP/device-loss/resources, physical IME/AT, paired performance, independent settings/support
narrowing and release handoff remain open in the canonical WIP. Failed and superseded receipts are
retained. No helper was installed into a real standard folder by these controls.

Hosted [run 39960920476](https://github.com/RedSalamanders/RedMonitor/actions/runs/39960920476)
at fd9adf929bdfd5e0d6e1c313b8fac472c31c5f4f failed before any job steps. Its check annotation confirms
account payment/spending-limit rejection, retained in [hosted-validation.json](hosted-validation.json).
This is a failed, account-blocked hosted gate; it supplies no runtime qualification. Repository visibility
and account settings were unchanged. Local native results above remain separately recorded.
