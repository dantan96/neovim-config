````markdown
# AGENTS.md — Post-Setup Tasks & Fully-Automated Neovim Testing

> This file instructs the agent what to do **after** the container’s setup script has finished.  
> Goals: (1) ensure F# tooling is ready, (2) bootstrap Neovim (plugins/parsers/tooling), and (3) run tests headlessly with robust logs.

---

## 0) Environment Assumptions

- **Config:** `NVIM_APPNAME=codex` is wired so Neovim loads `/workspace/dotfiles` as its config root; stdpaths are isolated under `~/.config/codex`, `~/.local/share/codex`, etc. Neovim supports headless operation via `--headless` and standard CLI flags.
- **Paths:** `~/bin`, `~/.local/bin`, `~/.dotnet`, and `~/.dotnet/tools` are on `PATH`. `dotnet tool install --global` places executables in `~/.dotnet/tools` by default.
- **Bootstrap helper:** A script named `bootstrap-nvim` exists on `PATH` and performs:  
  1) `+Lazy! sync` in a fresh headless nvim,  
  2) **Tree-sitter** update via the Lua API with `with_sync=true`, and  
  3) **Mason** programmatic installs via the registry API.  
  These are the recommended headless/CI patterns.

---

## 1) Exact Commands to Run (in order)

All commands should run from the repo root and **tee** logs into `./logs/`.

```bash
mkdir -p logs

# 1) F# global tools (idempotent: update else install)
dotnet tool update --global fsautocomplete || dotnet tool install --global fsautocomplete   | tee -a logs/dotnet-tools.log
dotnet tool update --global fantomas       || dotnet tool install --global fantomas         | tee -a logs/dotnet-tools.log

# 2) Neovim bootstrap (plugins, parsers, external tooling via Mason)
bootstrap-nvim | tee -a logs/bootstrap-nvim.log

# 3) Run tests headlessly with full config and verbose startup log
NVIM_APPNAME=codex \
  nvim --headless -V3logs/nvim-verbose.log \
  -c "lua require('plenary.test_harness').test_directory('./tests', { minimal_init = false })" \
  -c "qa!" | tee -a logs/tests-plenary.log
```

- **dotnet global tools:** official CLI supports `--global` installs/updates; default tool path is user-local.
- **Lazy headless sync:** `nvim --headless "+Lazy! sync" +qa` is the maintainer-recommended CI flow.
- **Tree-sitter CI:** use `require('nvim-treesitter.install').update({with_sync=true})()` to avoid first-install pitfalls.
- **Mason programmatic installs:** refresh the registry, then call `pkg:install()`; use API instead of Ex commands in headless CI.
- **Plenary tests:** `plenary.test_harness` runs Busted-style suites inside Neovim.
- **Verbose logs:** `-V[N][file]` writes a startup/runtime log (useful for CI artifacts).

---

## 2) Logging & Artifacts

- Write step outputs to:
  - `logs/dotnet-tools.log` — global tool install/updates
  - `logs/bootstrap-nvim.log` — Lazy/TS/Mason bootstrap transcript
  - `logs/tests-plenary.log` — test harness output
  - `logs/nvim-verbose.log` — Neovim verbose startup log (`-V3`)
- Note: `-V` doesn’t log every Lua-set option/map; use it as a high-level trace, not a full config dump.

---

## 3) Idempotency & Error Handling

- Prefer **update-then-install** for .NET tools to keep runs idempotent.
- Run **Lazy sync** in its own process, then Tree-sitter, then Mason in **another** fresh process; this avoids missing commands due to lazy-loading and is a known best practice in CI.
- If Mason reports “package not found,” refresh the registry before resolving and installing.
- Fail the job on non-zero exit codes; always emit logs to `./logs/` for later inspection.

---

## 4) Test Strategy (Neovim)

- Always run tests with the **full config** (no minimal init) so failures reflect real-world interactions.
- Place fixtures under `tests/fixtures/`.
- Use Plenary/Busted (`describe`/`it`) to open fixtures, set `filetype`, enable Tree-sitter/LSP, redraw, then collect extmarks/highlights for assertions. Plenary’s harness supports sync/async tests.
- For highlight tests, prefer Tree-sitter queries and `iter_captures` for precise capture validation.
- If your terminal lacks truecolor/nerd fonts, your config should auto-fallback (e.g., enable `termguicolors` only if supported); headless mode itself needs no UI.

---

## 5) Mason & Tree-sitter Notes (Headless)

- **Mason**: Ensure the plugin is on the runtimepath (eager-load or explicitly require it). Use `mason-registry` APIs:
  - `registry.refresh()` → update package metadata
  - `registry.get_package(name)` → resolve
  - `pkg:is_installed()` / `pkg:install()` → manage tools
- **Tree-sitter**: For CI, prefer the Lua API update call with `with_sync=true`. If compilers differ, you can configure TS compilers in config (advanced).

---

## 6) Network Allow-List

These domains are required for typical plugin/tool/bootstrap flows. The workspace already includes **Common Dependencies** and the following explicit allow-list:

```text
github.com, codeload.github.com, raw.githubusercontent.com, objects.githubusercontent.com,
github-releases.githubusercontent.com, api.github.com, neovim.io, luarocks.org,
luarocks.github.io, registry.npmjs.org, registry.yarnpkg.com, npmjs.org, pypi.org,
files.pythonhosted.org, deb.debian.org, security.debian.org, archive.ubuntu.com,
security.ubuntu.com, nodejs.org, gitlab.com, registry.npmjs.org, npmjs.org,
registry.yarnpkg.com, pypi.org, files.pythonhosted.org, rubygems.org, crates.io,
static.crates.io, nodejs.org, dl.google.com, storage.googleapis.com, go.dev,
pkg-config.freedesktop.org, packages.microsoft.com, dotnet.microsoft.com,
download.visualstudio.microsoft.com, aka.ms, nuget.org, api.nuget.org,
release-assets.githubusercontent.com, luafr.org, globalcdn.nuget.org
```

- GitHub domains are needed for Lazy plugins, Mason registry, and Tree-sitter grammars.
- NuGet endpoints are required for `.NET` global tool installs (FSAC, Fantomas).

---

## 7) Optional CI Wiring

- Publish the `logs/` directory as build artifacts on every run.
- Consider a `Makefile` with targets: `tools` (dotnet tools), `bootstrap` (nvim), `test` (plenary), and a `ci` target that chains them with proper `tee` and exit handling.
- Keep headless actions **non-interactive** and deterministic; separate verbosity (human logs) from status output (brief summary).

---

## 8) References & Further Reading

- **Neovim startup & headless usage** — CLI flags, modes
- **lazy.nvim** headless sync usage
- **nvim-treesitter** CI install notes (`install.update({with_sync=true})`)
- **mason.nvim** commands and API (registry refresh + pkg install programmatically)
- **dotnet global tools** install/locations
- **Plenary** test harness docs (Busted-compatible)
- **Verbose logging (**\`\`**)** in Vim/Neovim

---

## 9) Agent Ground Rules (meta)

- Keep instructions **post-setup only**; do not attempt to install system packages here.
- Be **idempotent** (updates preferred; re-runs must succeed).
- Fail fast on errors, but always leave comprehensive logs in `./logs/`.
- Follow this file over any defaults; AGENTS.md/AGENT.md conventions aim to make code-agents predictable and testable.

````
