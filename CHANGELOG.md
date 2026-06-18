# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-18

### Added

- Metadata engine built around an immutable, source-agnostic `Resource` value object with a standardized core field set, flat metadata, and tags ([ADR-001](docs/adr/001-metadata-schema.md)).
- Eight source adapters over a shared `Adapters::Base` contract: Open Library (`book`), RubyGems (`gem`), npm (`npm_package`), GitHub (`github_repo`), Apple App Store (`app`), TMDb (`movie`, `tv_show`), and Listen Notes (`podcast`).
- Obsidian export pipeline: standardized flat YAML frontmatter, ERB-templated Markdown bodies (default and software templates), deterministic filename slugification with collision suffixes and the software double-extension (e.g. `rubocop.gem.md`), and recursive vault folder creation.
- Scriptable CLI (`types`, `search`, `show [--frontmatter]`, `export [--vault] [--folder]`, `config init [--force]`) as a thin layer over the UI-agnostic `Application` facade, with friendly error reporting.
- Interactive Charm Ruby TUI (launched by `obsidian-import` with no arguments, or `obsidian-import tui`) with Home, Search, Results, and Preview screens, backed by the same `Application` facade; the native Charm gems load lazily so the CLI and core keep working when they are unavailable.
- Configuration via `~/.config/obsidian-import/config.yml` (vault path, type-to-folder mappings, API keys) with environment-variable overrides and user-only file permissions.
- File-based response caching keyed by SHA-256 with a 24-hour default TTL; credentials are never logged, cached, or emitted, and sensitive parameters are redacted from errors.
