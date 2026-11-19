- The winget block of `.ci/project.json` now declares a smoke test, `redmonitor --runtime-contract` with a
  120-second limit, as RedXe declares one (RedHome CV-6-07, register G-05). The engine runs it after a native winget
  install. The command is the headless check `package.ps1` already runs against every extracted Release package: it
  must exit 0 within 30 seconds with `PATH` limited to System32. Compiler-free checks pass.
