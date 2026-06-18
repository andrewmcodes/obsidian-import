# frozen_string_literal: true

require_relative "lib/obsidian/import/version"

Gem::Specification.new do |spec|
  spec.name = "obsidian-import"
  spec.version = Obsidian::Import::VERSION
  spec.authors = ["Andrew Mason"]
  spec.email = ["andrewmcodes@protonmail.com"]

  spec.summary = "Import structured metadata from canonical sources into an Obsidian vault."
  spec.description = "obsidian-import is a Ruby gem and terminal application for importing " \
    "structured metadata from canonical sources (Open Library, RubyGems, npm, GitHub, the " \
    "Apple App Store, TMDb, and Listen Notes) into an Obsidian vault as plain, human-editable " \
    "Markdown notes with standardized frontmatter. It ships a Charm Ruby TUI and a scriptable CLI."
  spec.homepage = "https://github.com/andrewmcodes/obsidian-import"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/andrewmcodes/obsidian-import"
  spec.metadata["changelog_uri"] = "https://github.com/andrewmcodes/obsidian-import/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "zeitwerk", "~> 2.6"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "dry-configurable", "~> 1.0"

  # Charm Ruby powers the interactive TUI. These are native extensions loaded
  # lazily by Obsidian::Import::TUI so the CLI/core still work if they are
  # unavailable on a given platform.
  spec.add_dependency "bubbletea", "~> 0.1"
  spec.add_dependency "lipgloss", "~> 0.2"
end
