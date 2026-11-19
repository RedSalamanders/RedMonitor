# Third-party notices

RedMonitor is copyright (c) 2026 RedSalamander, under the MIT license in [LICENSE.txt](LICENSE.txt). Its private
support code under `support/` is a snapshot of RedSalamander source under the same license; the original files and
hashes are recorded in [the source origin](Specs/SourceImport/source-origin.json). The components below are compiled
into or shipped with the package and keep their own terms. A new dependency or asset extends this list, with its full
notice, before it is distributed.

- **DxUi**, at the commit in [Dependencies/DxUi.lock.json](Dependencies/DxUi.lock.json), copyright (c) 2026
  RedSalamander, MIT. That revision compiles in WIL (below); toml++ 3.4.0, Mark Gillard, MIT; a math symbol table
  derived from KaTeX 0.16.11, Khan Academy and contributors, MIT; rapidyaml 0.16.0, Joao Paulo Magalhaes, MIT, with
  its bundled debugbreak (Scott Tsai, BSD 2-Clause) and fast_float (MIT) notices; tables generated from Unicode
  17.0.0, copyright Unicode, Inc., Unicode License V3; and an HTML named-character table from the WHATWG snapshot of
  18 October 2026, copyright WHATWG (Apple, Google, Mozilla, Microsoft), BSD 3-Clause for code and CC BY 4.0. The
  package carries DxUi's license and notices as `DxUi-LICENSE.txt`, `DxUi-THIRD-PARTY-NOTICES.md` and
  `DxUi-licenses\`. The full Unicode and WHATWG texts are in DxUi at that commit
  (`ThirdParty/Unicode/17.0.0/LICENSE.txt`, `ThirdParty/Markdown/whatwg-2026-10-18/LICENSE.txt`); the package does
  not stage them yet.
- **WIL** (Windows Implementation Libraries) 1.0.260126.7 or later, Microsoft Corporation, MIT, header-only. Its
  vcpkg copyright file ships as `wil-LICENSE.txt`.
- **yyjson** 0.13.0 or later, YaoYuan, MIT, shipped as `yyjson.dll`. Its vcpkg copyright file ships as
  `yyjson-LICENSE.txt`.
- The **Dracula** and **Catppuccin** color palettes, MIT, are described with their full licenses in
  [the theme notices](Specs/Themes/THIRD-PARTY-NOTICES.md) and ship under `Themes\`.
- The **Microsoft Visual C++ runtime** ships beside Release builds under the Microsoft Visual Studio
  distributable-code terms. Windows SDK and system libraries are used under Microsoft's terms.
