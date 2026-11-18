- Both vcpkg restores now use a complete clone of the pinned vcpkg repository instead of a `--filter=blob:none`
  partial clone. vcpkg 2026-07-27 extracts each versioned port with `git read-tree` and `git checkout-index` in an
  environment that holds only `GIT_INDEX_FILE`; without `SystemRoot` that Git resolves no host, so a blob the
  partial clone left on the server failed the restore with "Could not resolve host: github.com". It started on
  2026-11-18, when upstream `master` (microsoft/vcpkg de36db0455) stopped carrying the `vcpkg-cmake` tree the
  baseline selects, and stopped every fresh restore. `vcpkg-install.ps1` clones completely, fetches the pinned
  commit without `--depth` only when it is missing, and completes an earlier partial checkout in place. The pinned
  DxUi installer still makes a partial clone, so `restore-dxui.ps1` first prepares its `<output>/vcpkg-tool` as a
  complete checkout at DxUi's pinned vcpkg commit (`Build/VcpkgToolCheckout.psm1`, the same file in every DxUi
  consumer), which that installer reuses. `Tests/Tooling.Tests.Vcpkg.ps1` checks the preparation offline against a
  `file://` registry, extracting an older tree the way vcpkg does, and pins both scripts. Native compile: the
  post-merge qualification.
