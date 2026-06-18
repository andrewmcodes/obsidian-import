# ADR-001: Metadata Schema

- Status: Accepted
- Date: 2026-06-18
- Owner: Andrew Mason

## Context

`obsidian-import` pulls structured metadata from many canonical sources (Open Library, RubyGems, npm, GitHub, the Apple App Store, TMDb, Listen Notes) and writes it into an Obsidian vault as plain, human-editable Markdown. Each source has its own response shape, field names, and identifiers. Without a single normalized schema, every adapter would emit differently-shaped notes, frontmatter keys would drift, and notes would be hard to query consistently in Obsidian (which treats frontmatter as flat YAML properties). We also need notes to remain portable and plugin-independent: plain Markdown with a predictable frontmatter block and a templated body.

This ADR defines the standardized metadata schema that the core (`Obsidian::Import::Resource`) and the export pipeline (`Export::Frontmatter`, `Export::Filename`, `Export::Template`) implement today, so that the engine stays UI-agnostic and every adapter — current and future — produces uniform output.

## Decision

### Normalized resource

Every adapter normalizes a raw API record into a single immutable value object, `Obsidian::Import::Resource`, regardless of source. A Resource carries the standardized core fields plus a free-form `metadata` hash for source-specific values and an array of `tags`. Two resources with equal fields are equal.

### Standardized frontmatter schema and canonical core field order

Notes begin with a YAML frontmatter block delimited by `---`. The core fields are emitted first, always in this canonical order (`Resource#core_fields` and `Export::Frontmatter::CORE_ORDER`):

1. `type`
2. `subtype`
3. `title`
4. `description`
5. `source`
6. `source_id`
7. `source_url`

After the core fields come the flattened adapter-specific metadata keys (in the order the adapter declared them), and `tags` is always emitted last. A representative frontmatter block for a gem:

```yaml
---
type: gem
subtype: gem
title: view_component
description: A framework for building reusable, testable & encapsulated view components in Ruby on Rails.
source: RubyGems
source_id: view_component
source_url: https://github.com/viewcomponent/view_component
version: 4.0.0
downloads: 123456789
authors:
  - GitHub Open Source
homepage_url: https://viewcomponent.org
github_url: https://github.com/viewcomponent/view_component
documentation_url: https://viewcomponent.org
licenses:
  - MIT
tags:
  - gem
---
```

Field semantics:

- `type` — the object type, e.g. `book`, `gem`, `npm_package`, `github_repo`, `app`, `movie`, `tv_show`, `podcast`.
- `subtype` — finer-grained classification within a type (may be `null`); see subtype conventions below.
- `title` — human-readable title.
- `description` — short summary (may be `null`).
- `source` — the canonical source name, e.g. `RubyGems`, `Open Library`, `TMDb`.
- `source_id` — the stable identifier within the source (gem name, GitHub `owner/repo`, TMDb numeric id, Open Library work key, etc.).
- `source_url` — canonical URL of the record on the source (may be `null`).
- `tags` — an array of note tags, always rendered last.

The frontmatter must remain human-readable: long values are not hard-wrapped (rendered with `line_width: -1`), and the block stays flat.

### Metadata-flattening rule (no nested objects)

Adapter-specific metadata is flattened directly into the top level of the frontmatter — there are no nested objects. This keeps every value addressable as a first-class Obsidian property. Concretely:

- Each `metadata` key is stringified and emitted as a top-level frontmatter key. Keys that would collide with a core field name or with `tags` are skipped (core fields and `tags` always win).
- `Resource` drops `nil` and empty values from `metadata` at construction time, so blank fields never appear in frontmatter.
- Values are coerced into frontmatter-safe scalars and arrays (`Export::Frontmatter.scalarize`): arrays are preserved (with any nested hash elements collapsed to their string form), and a nested `Hash` value is collapsed to its string representation rather than emitted as nested YAML.
- Because nested objects are disallowed, adapters must do their own flattening: dig into nested API payloads and assign the extracted scalar/array to a flat metadata key (for example GitHub uses `record.dig("license", "spdx_id")` to produce a flat `license` string, and `record.dig("owner", "login")` for `owner`).

### Subtype conventions

`subtype` provides finer classification within a `type` and drives the software double-extension filename (below). Conventions in the current adapters:

- Software-object types set `subtype` to a short token naming the software kind: `gem` (RubyGems), `npm` (npm), `app` (Apple App Store).
- The `github_repo` type currently leaves `subtype` unset (`null`).
- Non-software types (`book`, `movie`, `tv_show`, `podcast`) leave `subtype` unset (`null`).
- Reserved subtype tokens for software objects, per the product spec, are: `app`, `cli`, `extension`, `gem`, `npm`. Future adapters classifying software should reuse these tokens rather than inventing synonyms.

### Filename generation rules

Filenames are slugified deterministically from the title (`Export::Filename`):

1. Convert to lowercase.
2. Replace spaces and any other non-`[a-z0-9]` separators with hyphens.
3. Strip invalid characters: only ASCII letters, numbers, and hyphens survive. Runs of hyphens are squeezed to one, and leading/trailing hyphens are trimmed.
4. An empty result falls back to `untitled`.
5. The default extension is `.md`.
6. Collisions are resolved with numeric suffixes: if `slug.md` exists, try `slug-2.md`, `slug-3.md`, and so on.

Examples:

- `Rails` → `rails.md`
- `Ruby on Rails` → `ruby-on-rails.md`
- `@changesets/cli` → `changesets-cli.md`
- collisions: `rails.md`, then `rails-2.md`, `rails-3.md`, ...

#### Software double-extension

Software-object notes use a double extension that embeds the `subtype` between the slug and the `.md` extension, producing names like `rubocop.gem.md`, `raycast.app.md`, and `changesets-cli.npm.md`. This applies to the software types (`gem`, `npm_package`, `github_repo`, `app`) when a `subtype` is present (`Export::Note#secondary_extension` and `Export::Template::SOFTWARE_TYPES`); collisions still take a numeric suffix on the slug, e.g. `rubocop-2.gem.md`. A software type with no `subtype` (such as the current `github_repo`) falls back to the plain `slug.md` form.

### Type to folder mapping conventions

Each `type` maps to a vault-relative folder. Missing folders are created recursively at export time. The default mapping (`Configuration::DEFAULT_FOLDERS`) is:

| Type           | Folder                |
| -------------- | --------------------- |
| `book`         | `Books`               |
| `gem`          | `Gems`                |
| `npm_package`  | `npm Packages`        |
| `github_repo`  | `GitHub Repositories` |
| `app`          | `Apps`                |
| `movie`        | `Movies`              |
| `tv_show`      | `TV Shows`            |
| `podcast`      | `Podcasts`            |

Users can override any mapping in their config file under `folders:`, and the `export` command accepts a one-off `--folder` override. An unknown type with no configured folder falls back to a folder named after the type itself.

### Note body

The Markdown body is rendered from an ERB template chosen by type (`Export::Template`). Software types (`gem`, `npm_package`, `github_repo`, `app`) use `software.md.erb`; all other types use `default.md.erb`. Templates are side-effect free and receive only the `resource`. The full note is the frontmatter block followed by the rendered body.

## Consequences

- Every note in the vault has the same predictable, flat frontmatter shape, so Obsidian properties, queries, and bases work uniformly across object types.
- Adapters stay small: their only schema responsibility is to map a raw record onto the core fields plus a flat `metadata` hash and `tags`. Shared HTTP, caching, credential handling, frontmatter rendering, filename generation, and folder routing live in the core.
- The no-nested-objects rule forces adapters to flatten nested API payloads themselves. Adapters must extract scalars/arrays (e.g. via `dig`) instead of passing nested hashes through; any hash that slips through is collapsed to a string rather than emitted as nested YAML.
- Filenames are stable and filesystem-safe, and the software double-extension makes software notes self-describing on disk.
- Adding a new object type means: define its folder mapping, register its adapter, and ensure the adapter conforms to this schema — no changes to the export pipeline.
- This ADR is binding: all future adapters must comply with it. Any change to the core field set, the canonical order, the flattening rule, the filename rules, or the folder conventions requires a new ADR superseding this one.
