# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0](https://github.com/andrewmcodes/obsidian-import/compare/obsidian-import-v0.1.0...obsidian-import/v0.2.0) (2026-06-19)


### Features

* **adapters:** add VS Code extensions adapter ([748cddb](https://github.com/andrewmcodes/obsidian-import/commit/748cddb214b57d93bfcb570eaeea60cecb839a7b))
* add application facade and command-line interface ([1defa0e](https://github.com/andrewmcodes/obsidian-import/commit/1defa0e8c7bfb0e9ce46d23e9c1349bb3bc84324))
* add interactive Charm Ruby TUI ([5023a25](https://github.com/andrewmcodes/obsidian-import/commit/5023a256f82acf14d367c6af259e30f7f534085e))
* add metadata engine, source adapters, and Obsidian export ([a3269de](https://github.com/andrewmcodes/obsidian-import/commit/a3269deabe986ad03cb4846224b614851044b5ac))
* **github:** prefer the gh CLI for GitHub API requests ([a952350](https://github.com/andrewmcodes/obsidian-import/commit/a952350573a1d73e8fceb15d7fc3743a16e9a0a8))
* **http:** add POST support to the HTTP client ([98a6e1a](https://github.com/andrewmcodes/obsidian-import/commit/98a6e1a76d81fa9ff885d11955d290cbec21df20))


### Bug Fixes

* **ci:** lock Linux and macOS platforms for the Charm native gems ([6fc29db](https://github.com/andrewmcodes/obsidian-import/commit/6fc29db943aab1049518c681eedbbec1d5900471))
* harden adapters, export, caching, config, and CLI from review ([68db262](https://github.com/andrewmcodes/obsidian-import/commit/68db2620fb30d917ea3f79bba1cc420eecc3950a))

## [Unreleased]

### Added

- VS Code extensions adapter (`vscode_extension`), sourced from the Visual Studio Marketplace gallery API. Notes use the software template and a `<slug>.extension.md` filename, and land in the "VS Code Extensions" folder by default.

### Changed

- The GitHub adapter now prefers the `gh` CLI (`gh api`) when it is installed and authenticated, reusing the user's gh credentials, and falls back to a direct HTTP request otherwise. Set `OBSIDIAN_IMPORT_NO_GH=1` to force the HTTP path.

### Fixed

- Added Linux and macOS platforms to `Gemfile.lock` so the precompiled Charm (TUI) native gems install on CI and other platforms instead of attempting a from-source build.

## [0.1.0] - 2026-06-18

### Added

- Metadata engine built around an immutable, source-agnostic `Resource` value object with a standardized core field set, flat metadata, and tags ([ADR-001](docs/adr/001-metadata-schema.md)).
- Eight source adapters over a shared `Adapters::Base` contract: Open Library (`book`), RubyGems (`gem`), npm (`npm_package`), GitHub (`github_repo`), Apple App Store (`app`), TMDb (`movie`, `tv_show`), and Listen Notes (`podcast`).
- Obsidian export pipeline: standardized flat YAML frontmatter, ERB-templated Markdown bodies (default and software templates), deterministic filename slugification with collision suffixes and the software double-extension (e.g. `rubocop.gem.md`), and recursive vault folder creation.
- Scriptable CLI (`types`, `search`, `show [--frontmatter]`, `export [--vault] [--folder]`, `config init [--force]`) as a thin layer over the UI-agnostic `Application` facade, with friendly error reporting.
- Interactive Charm Ruby TUI (launched by `obsidian-import` with no arguments, or `obsidian-import tui`) with Home, Search, Results, and Preview screens, backed by the same `Application` facade; the native Charm gems load lazily so the CLI and core keep working when they are unavailable.
- Configuration via `~/.config/obsidian-import/config.yml` (vault path, type-to-folder mappings, API keys) with environment-variable overrides and user-only file permissions.
- File-based response caching keyed by SHA-256 with a 24-hour default TTL; credentials are never logged, cached, or emitted, and sensitive parameters are redacted from errors.
