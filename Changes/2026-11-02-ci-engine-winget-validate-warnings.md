- Adopt shared CI engine `1a42715`, whose native winget proof accepts validate's succeeded-with-warnings
  code (`0x8A150028`), records the hosted winget version and prints the log of any failing owned command.
  The hosted runners' winget still reported that code for `v0.1.82` after schema headers were added, so no
  submission occurred. Only the engine pin and generated callers change; publication still requires a fresh
  main qualification under this engine.
