# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
  add_filter "/lib/obsidian/import/version.rb"
  # The TUI is an interactive shell over the tested core; exclude it from the
  # coverage gate since it cannot run headless in CI.
  add_filter "/lib/obsidian/import/tui/"
  add_group "Adapters", "lib/obsidian/import/adapters"
  add_group "Obsidian", "lib/obsidian/import/obsidian"
  add_group "Core", "lib/obsidian/import"
  minimum_coverage line: 90
end

require "tmpdir"
require "obsidian/import"

require "webmock/rspec"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = File.expand_path("fixtures/vcr_cassettes", __dir__)
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {record: :none}

  # Never persist credentials into cassettes.
  config.filter_sensitive_data("<TMDB_API_KEY>") { ENV["TMDB_API_KEY"] }
  config.filter_sensitive_data("<GITHUB_TOKEN>") { ENV["GITHUB_TOKEN"] }
  config.filter_sensitive_data("<LISTEN_NOTES_API_KEY>") { ENV["LISTEN_NOTES_API_KEY"] }
  config.before_record do |interaction|
    interaction.request.headers.delete("Authorization")
    interaction.request.headers.delete("X-Listenapi-Key")
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  Kernel.srand config.seed

  # Isolate every example from the developer's real config/cache/vault by
  # pointing XDG dirs at a per-example temporary directory. Examples that do
  # not opt into VCR (via `:vcr` metadata) run with VCR turned off so plain
  # WebMock stubs pass through untouched.
  config.around do |example|
    Dir.mktmpdir("obsidian-import-spec") do |dir|
      original = ENV.to_hash
      ENV["XDG_CONFIG_HOME"] = File.join(dir, "config")
      ENV["XDG_CACHE_HOME"] = File.join(dir, "cache")
      # Force the deterministic HTTP path for GitHub by default so examples
      # never shell out to a real `gh`; gh-path examples opt back in explicitly.
      ENV[Obsidian::Import::GhRunner::DISABLE_ENV] = "1"
      Obsidian::Import.reset_configuration!
      begin
        if example.metadata[:vcr]
          example.run
        else
          VCR.turned_off { example.run }
        end
      ensure
        ENV.replace(original)
        Obsidian::Import.reset_configuration!
      end
    end
  end
end
