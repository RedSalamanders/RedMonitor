- Converged the root files with every RedSalamanders repository (convergence CV-6-03, owner decision D18 and the
  B-12 default): `LICENSE.txt` is now only the common MIT text naming RedSalamander, and the new
  `THIRD-PARTY-NOTICES.md` lists what the package actually ships (DxUi and the components that revision compiles
  in, WIL, yyjson, the Dracula and Catppuccin palettes and the Visual C++ runtime), replacing a copied list that named
  18 components RedMonitor never shipped. `package.ps1` stages the notices file beside `LICENSE.txt`. The common
  `CONTRIBUTING.md`, pull request template and `.vsconfig` are added. Consumers keep the licence their
  `RedMonitor.lock.json` pins until they next update the client. Validated with `validate.ps1` and
  `Tools/Test-Changelog.ps1`; native packaging runs in main qualification.
