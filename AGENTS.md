# AGENTS.md

This is the contributor and agent guide for `obsidian-import`. It is written so that a coding agent can implement a brand-new source adapter end to end using only this file plus [ADR-001](docs/adr/001-metadata-schema.md), which defines the metadata schema every adapter must comply with. Read ADR-001 before writing an adapter.

## What this gem does

`obsidian-import` imports structured metadata from canonical sources into an Obsidian vault as plain, human-editable Markdown notes with standardized frontmatter. It ships a scriptable CLI, and is designed to be driven equally well by a TUI, an MCP server, or any other front end.

## Architecture

The design is a strict layering, with a UI-agnostic core at the center:

```
front ends (CLI, future TUI/MCP)  ->  Application  ->  Registry  ->  Adapters  ->  HTTP::Client  ->  external APIs
                                                                         |
                                                          Resource (normalized value object)
                                                                         |
                                                       Export pipeline (Frontmatter, Template, Filename, Exporter)  ->  Obsidian vault
```

- The metadata engine never depends on a UI framework or on Obsidian. The `Configuration` object, `Resource`, the adapters, and the export pipeline are all plain Ruby.
- `Obsidian::Import::Application` is the single high-level facade. Every front end drives the library through it so behavior stays identical across interfaces. It resolves adapters via the `Registry`, runs `search`/`lookup`, renders notes, and writes them to the vault.
- The CLI (`Obsidian::Import::CLI`) is a thin layer over `Application`: it parses argv, calls the facade, formats output, and renders all library errors as friendly messages (never backtraces). A TUI, when present, is expected to be an equally thin layer over the same `Application`.
- Adapters translate one external API into normalized `Resource` objects. They are the only place that knows a source's response shape.
- `HTTP::Client` is shared plumbing: JSON-over-Faraday GETs with default headers/params, error mapping onto the library error hierarchy, response caching, and redaction of sensitive params.

## Repository layout

```
exe/obsidian-import                 # CLI entry point (calls CLI.start(ARGV))
lib/obsidian/import.rb              # Zeitwerk setup, error classes, configuration accessors
lib/obsidian/import/
  version.rb                        # VERSION constant
  configuration.rb                  # dry-configurable settings: vault_path, folders, api_keys, cache_ttl
  cache.rb                          # file-based SHA-256 keyed response cache
  resource.rb                       # the normalized value object every adapter produces
  registry.rb                       # type -> adapter/label/requires_key catalog
  application.rb                    # UI-agnostic facade
  cli.rb                            # CLI front end
  http/client.rb                    # Faraday wrapper: JSON, errors, caching, redaction
  adapters/
    base.rb                         # abstract adapter contract + shared helpers
    open_library.rb ruby_gems.rb npm.rb github.rb apple.rb tmdb.rb listen_notes.rb
  export/
    exporter.rb frontmatter.rb template.rb note.rb filename.rb
  templates/
    default.md.erb software.md.erb
sig/obsidian/                       # RBS signatures
spec/                               # RSpec suite (mirrors lib/)
docs/adr/001-metadata-schema.md     # the metadata schema ADR
```

Zeitwerk autoloads everything under `lib`. Custom inflections are declared in `lib/obsidian/import.rb` (`CLI`, `TUI`, `HTTP`, `Npm`, `GitHub`, `TMDb`, `URL`); if you add a class whose constant casing does not match Zeitwerk's default, add an inflection there.

## The Adapter contract

A source adapter is a subclass of `Obsidian::Import::Adapters::Base`. The base class supplies HTTP, caching, credential handling, and the `Resource` builder, so a typical adapter is one small file. To write one:

1. Subclass `Adapters::Base`.
2. Declare the object type(s) with `object_types` and the canonical source name with `source_name`.
3. Implement the public contract: `#search(query:)`, `#lookup(id:)`, and `#normalize(record:)`.
4. Build resources with the `#build` helper (it stamps the adapter's `type` and `source` for you).
5. For keyed sources, fetch credentials with `#require_credential!`.
6. Override the private hooks as needed: `#base_url` (required), and optionally `#request_headers` and `#request_params`.

Method responsibilities:

- `#search(query:)` returns an `Array<Resource>`. Fetch the source's search endpoint, then map each raw record through `#normalize`.
- `#lookup(id:)` returns a single `Resource` for a source identifier. Fetch the source's lookup endpoint and pass the record through `#normalize`.
- `#normalize(record:)` maps one raw API record onto a `Resource` via `#build`. This is the only method that knows the source's field names. It must comply with ADR-001: set the core fields, put source-specific values into a flat `metadata` hash (no nested objects — flatten with `dig` and friends), and set `tags`.

Helpers provided by `Base`:

- `#build(title:, source_id:, subtype: nil, description: nil, source_url: nil, metadata: {}, tags: [], type: @type)` — constructs a `Resource` with this adapter's `source` and `type`. For multi-type adapters, pass `type:` explicitly (see TMDb).
- `#require_credential!(name)` — returns the credential for a logical key (`:tmdb`, `:github`, `:listen_notes`) or raises `MissingCredentialError` with a friendly hint naming the env var. Call it from `#request_headers`/`#request_params` so the client is built with the credential attached.
- `#client` — lazily builds an `HTTP::Client` from `#base_url`, `#request_headers`, `#request_params`, the cache, and `source`. Use `client.get(path, params: {...})` and it returns parsed JSON. The client maps non-2xx responses onto `AuthenticationError` (401/403), `NotFoundError` (404), `RateLimitError` (429), `ResponseError` (other/malformed), and transport failures onto `NetworkError`.

Private hooks you may override:

- `#base_url` — required; the API base URL.
- `#request_headers` — default headers sent with every request (defaults to `{}`). Use for `Accept`, `User-Agent`, or a credential header (Listen Notes sends `X-ListenAPI-Key`; GitHub sends an optional `Authorization: Bearer` token).
- `#request_params` — default query params sent with every request (defaults to `{}`). Use for query-param credentials (TMDb sends `api_key`). Param names listed in `HTTP::Client::SENSITIVE_PARAMS` (`api_key`, `apikey`, `key`, `token`, `access_token`) are excluded from cache keys and redacted from errors.

### Worked example

This mirrors `lib/obsidian/import/adapters/ruby_gems.rb`, the simplest credential-free adapter. A hypothetical "Crates.io" adapter for Rust crates would look like:

```ruby
# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for the {https://crates.io crates.io} registry.
      #
      # Supports the +crate+ object type. Requires no credentials.
      class Crates < Base
        object_types "crate"
        source_name "crates.io"

        # @return [String]
        BASE_URL = "https://crates.io/api/v1"

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          response = client.get("/crates", params: {q: query, per_page: 10})
          Array(response["crates"]).map { |record| normalize(record: record) }
        end

        # @param id [String] the crate name
        # @return [Resource]
        def lookup(id:)
          normalize(record: client.get("/crates/#{id}")["crate"])
        end

        # @param record [Hash] a crates.io crate object
        # @return [Resource]
        def normalize(record:)
          name = record["name"]
          build(
            title: name,
            subtype: "crate",
            source_id: name,
            description: record["description"],
            source_url: "https://crates.io/crates/#{name}",
            metadata: {
              "version" => record["max_stable_version"] || record["newest_version"],
              "downloads" => record["downloads"],
              "homepage_url" => record["homepage"],
              "documentation_url" => record["documentation"],
              "github_url" => record["repository"]
            },
            tags: ["crate"]
          )
        end

        private

        def base_url
          BASE_URL
        end
      end
    end
  end
end
```

Notes on the example, all per ADR-001: `metadata` is flat (no nested objects); `nil`/empty values are dropped automatically by `Resource`, so you do not need to guard them; `subtype` of `crate` would drive a `name.crate.md` filename only if `crate` is a software type — see the registration step.

### Registering the type

A new type is invisible until it is added to the central catalog in `lib/obsidian/import/registry.rb`. Add one entry to `Registry::TYPES`:

```ruby
"crate" => {adapter: "Adapters::Crates", label: "Rust Crate", requires_key: false},
```

- `adapter` — the constant path under `Obsidian::Import` (resolved with `const_get`).
- `label` — the human-readable name shown by `obsidian-import types`.
- `requires_key` — `true` only if the source needs a credential; this drives the "(requires API key)" hint and is exposed via `Application#types`.

Then wire the type into the rest of the schema, per ADR-001:

- Add a default folder for the type in `Configuration::DEFAULT_FOLDERS` (and the template YAML lists the same defaults).
- If the type is a software object that should use the software body template and the double-extension filename, add it to `Export::Template::SOFTWARE_TYPES`.
- If the source needs a credential, add a logical-key-to-env-var mapping in `Configuration::ENV_KEYS`.

## Coding standards

- Lint with StandardRB. Run `mise run lint`; auto-fix with `mise run format`. The `.standard.yml` targets `ruby_version: 3.2`.
- Every Ruby file starts with `# frozen_string_literal: true`.
- All public classes, modules, and methods carry YARD documentation (see below).
- Use the standard-library `JSON`; do not add `Oj` (or other JSON libs) without a profiling-backed need.
- Keep the core UI-agnostic: nothing in the engine, adapters, or export pipeline may depend on a UI framework or on Obsidian.

## Testing requirements

- RSpec, with specs mirroring `lib/` under `spec/`. Run `mise run test` (or `bundle exec rspec`).
- HTTP is stubbed with WebMock; no live API calls run in CI. The suite supports VCR, but the `spec_helper` runs every example with `VCR.turned_off` unless the example opts in with `:vcr` metadata — so for a normal adapter spec, write plain `stub_request(...)` WebMock stubs and they pass through untouched. Cassettes (when used) live under `spec/fixtures/vcr_cassettes`, and the VCR config filters/strips credentials so secrets never land in fixtures.
- Each example is isolated from your real environment: `XDG_CONFIG_HOME`/`XDG_CACHE_HOME` are pointed at a per-example tempdir and the memoized configuration is reset around each run.
- Coverage is enforced by SimpleCov at a minimum of 90% lines (branch coverage enabled). A new adapter needs specs covering `search`, `lookup`, and `normalize` (including credential-missing behavior for keyed sources and any field-flattening edge cases). The TUI directory is excluded from the coverage gate.

## RBS and Steep conventions

- Type signatures live under `sig/` mirroring `lib/`. Public APIs must have signatures.
- Type-check with `mise run typecheck` (`bundle exec steep check`).
- When you add a public class or change a public signature, add or update the corresponding `.rbs`. The adapter contract in RBS terms:

```rbs
def search: (query: String) -> Array[untyped]
def lookup: (id: String) -> untyped
def normalize: (record: untyped) -> Resource
```

## YARD conventions

- Generate docs with `mise run docs` (`bundle exec yard doc`). `.yardopts` configures Markdown markup, includes the ADRs and `CHANGELOG.md`, documents protected members, and uses `README.md` as the front page.
- Document every public class, module, and method with a summary plus `@param`/`@return`/`@raise` tags as appropriate. Match the density already present in `lib/` (the adapters and `Base` are good references).

## mise workflows

`mise.toml` defines the developer tasks (Ruby is pinned via mise):

- `mise run test` — RSpec suite.
- `mise run lint` — StandardRB.
- `mise run format` — StandardRB auto-correct.
- `mise run typecheck` — Steep against the RBS signatures.
- `mise run docs` — YARD documentation.
- `mise run ci` — the full pipeline: `lint`, `typecheck`, then `test`.

Run `mise run ci` before opening a pull request.

## API credentials and security

Credentials are resolved by `Configuration#api_key`, which prefers environment variables over the config file. The keyed sources and their env vars:

- TMDb (`movie`, `tv_show`) — `TMDB_API_KEY` (logical key `tmdb`), sent as the `api_key` query param.
- GitHub (`github_repo`) — `GITHUB_TOKEN` (logical key `github`), sent as `Authorization: Bearer`; optional (raises rate limits when present).
- Listen Notes (`podcast`) — `LISTEN_NOTES_API_KEY` (logical key `listen_notes`), sent as the `X-ListenAPI-Key` header.

Security requirements every adapter must uphold:

- Never log, cache, or emit credentials. Only response payloads are ever cached; credentials are not.
- The `HTTP::Client` redacts `SENSITIVE_PARAMS` from error messages and excludes them from cache keys. If a source carries a secret in an unusual param name, extend `SENSITIVE_PARAMS`. Secrets carried in headers are never part of the cache key.
- Credentials must never appear in generated notes.
- Config files are created with user-only permissions (`0600`) on platforms that support it.
- Errors shown to users are friendly messages, never raw exceptions or backtraces; sensitive values are always redacted.

## Release process

1. Bump the version in `lib/obsidian/import/version.rb`.
2. Update `CHANGELOG.md`: move the relevant entries from `[Unreleased]` into a new dated version section (Keep a Changelog format).
3. Ensure `mise run ci` is green.
4. Build and release the gem via Rake: `bundle exec rake release` (creates the git tag, pushes commits and tag, and pushes the `.gem` to RubyGems.org). The gemspec sets `rubygems_mfa_required`, so MFA is required at publish time.

## Contributing

Bug reports and pull requests are welcome at <https://github.com/andrewmcodes/obsidian-import>. Contributors are expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
