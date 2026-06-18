# obsidian-import

`obsidian-import` imports structured metadata from canonical sources into an [Obsidian](https://obsidian.md) vault as plain, human-editable Markdown notes with standardized frontmatter. Search a source, preview the metadata, and write a portable note into your vault — no scraping, no proprietary storage, and no required plugins.

It ships a scriptable CLI for automation, and the metadata engine is UI-agnostic so it can be driven from a TUI, an MCP server, or any other front end.

## Supported object types and their sources

Every object type has a single canonical source of truth, queried through that source's official API:

| Type          | Source              |
| ------------- | ------------------- |
| `book`        | Open Library        |
| `gem`         | RubyGems            |
| `npm_package` | npm                 |
| `github_repo` | GitHub              |
| `app`         | Apple App Store     |
| `movie`       | TMDb                |
| `tv_show`     | TMDb                |
| `podcast`     | Listen Notes        |

Notes follow a standardized, flat frontmatter schema (core fields, then flattened source-specific metadata, then tags) defined in [ADR-001](docs/adr/001-metadata-schema.md).

## Installation

Install the gem and add it to your application's Gemfile by executing:

```bash
bundle add obsidian-import
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install obsidian-import
```

This installs the `obsidian-import` executable. The gem requires Ruby 3.2 or newer.

## Configuration

Configuration lives at `~/.config/obsidian-import/config.yml` (honoring `XDG_CONFIG_HOME`). Create a starter file with:

```bash
obsidian-import config init
```

This writes a commented template with user-only (`0600`) permissions. Pass `--force` to overwrite an existing file. The file looks like:

```yaml
# obsidian-import configuration
# Path to your Obsidian vault. Required to create notes.
vault_path: ~/Documents/Obsidian

# Vault-relative folder for each object type.
folders:
  book: Books
  gem: Gems
  npm_package: npm Packages
  github_repo: GitHub Repositories
  app: Apps
  movie: Movies
  tv_show: TV Shows
  podcast: Podcasts

# API credentials. Prefer environment variables for secrets:
#   TMDB_API_KEY, GITHUB_TOKEN, LISTEN_NOTES_API_KEY
api_keys:
  tmdb: ""
  github: ""
  listen_notes: ""
```

Settings, in order of precedence: explicit runtime configuration, environment variables, the YAML file, then built-in defaults.

- `vault_path` — your Obsidian vault root. Required to write notes. Overridable with the `OBSIDIAN_VAULT` environment variable.
- `folders` — vault-relative folder per object type. Your overrides merge over the defaults shown above.
- `api_keys` — credentials for the keyed sources. Prefer the environment variables over committing secrets to the file.

### API credentials

Three sources accept credentials, resolved from the environment first, then the config file:

| Source       | Used by              | Environment variable    | Required?                         |
| ------------ | -------------------- | ----------------------- | --------------------------------- |
| TMDb         | `movie`, `tv_show`   | `TMDB_API_KEY`          | Yes                               |
| Listen Notes | `podcast`            | `LISTEN_NOTES_API_KEY`  | Yes                               |
| GitHub       | `github_repo`        | `GITHUB_TOKEN`          | Optional (raises rate limits)     |

Credentials are never logged, cached, or written into generated notes, and are redacted from error output.

## CLI usage

```bash
obsidian-import types                                   # list supported object types
obsidian-import search <type> <query>                   # search a source
obsidian-import show <type> <id> [--frontmatter]        # render a note (or just its frontmatter)
obsidian-import export <type> <id> [--vault PATH] [--folder NAME]  # write a note into the vault
obsidian-import config init [--force]                   # create the config file
obsidian-import --help                                  # show usage
obsidian-import --version                               # show the version
```

### Examples

List the supported types and which require an API key:

```bash
obsidian-import types
```

Search a source — results are numbered, with a truncated description and the source URL:

```bash
obsidian-import search gem view_component
obsidian-import search book "the pragmatic programmer"
obsidian-import search github_repo rails
```

Render a note to stdout, or just its YAML frontmatter:

```bash
obsidian-import show gem view_component
obsidian-import show gem view_component --frontmatter
```

Write a note into your vault. `<id>` is the source identifier (gem name, GitHub `owner/repo`, TMDb numeric id, Open Library work key, etc.). The target folder comes from the type-to-folder mapping unless overridden:

```bash
obsidian-import export gem view_component
obsidian-import export github_repo rails/rails
obsidian-import export movie 27205 --vault ~/Vaults/Research --folder "Watchlist"
```

On success, `export` prints the absolute path of the note it created. All library errors (missing credentials, no vault configured, network failures, rate limits) are reported as friendly messages, and the process exits non-zero on failure.

### Interactive use

Running `obsidian-import` with no arguments is reserved for an interactive [Charm Ruby](https://github.com/charmbracelet) TUI — a Spotlight/Raycast-style flow to pick a type, search live, preview metadata, and create a note. The same `Application` facade backs both the CLI and the TUI, so behavior is identical across interfaces.

## How notes are written

- The note filename is slugified from the title (lowercased, separators to hyphens, invalid characters stripped), with numeric suffixes resolving collisions. Software objects get a double extension, e.g. `rubocop.gem.md`.
- The destination folder is created recursively if missing.
- The frontmatter is a flat YAML block: core fields first, then flattened source-specific metadata, then `tags`. See [ADR-001](docs/adr/001-metadata-schema.md) for the full schema.
- Responses are cached on disk under `~/.cache/obsidian-import` (honoring `XDG_CACHE_HOME`) with a 24-hour default TTL. Cached data never contains credentials.

## Development

After checking out the repo, install dependencies with `bin/setup`. Workflows are exposed through [mise](https://mise.jdx.dev):

```bash
mise run test        # run the RSpec suite
mise run lint        # run StandardRB
mise run format      # auto-correct style with StandardRB
mise run typecheck   # run Steep against the RBS signatures
mise run docs        # generate YARD documentation
mise run ci          # full pipeline: lint, typecheck, test
```

You can also run `bin/console` for an interactive prompt. To install the gem locally, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/andrewmcodes/obsidian-import>. The contributor and agent guide — including the adapter contract and how to add a new source — is in [AGENTS.md](AGENTS.md).

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the obsidian-import project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
