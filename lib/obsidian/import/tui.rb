# frozen_string_literal: true

module Obsidian
  module Import
    # The interactive terminal UI, built on Charm Ruby (Bubble Tea + Lip Gloss).
    #
    # The TUI is a thin front end over {Application}: it drives the same
    # search/lookup/render/export operations the CLI uses, presented as a
    # Spotlight/Raycast-style flow (pick a type, search live, preview, create).
    #
    # The Charm gems are native extensions and are loaded lazily here so that a
    # missing or unbuildable binary degrades gracefully (with a friendly
    # message) instead of breaking the CLI or the core engine.
    module TUI
      # Launch the interactive TUI.
      #
      # @param application [Application]
      # @param out [IO] stream for failure messages when the UI cannot start
      # @return [Integer] process exit status (0 success, 1 if the UI is unavailable)
      def self.start(application: Application.new, out: $stdout)
        require "bubbletea"
        require "lipgloss"
        Bubbletea.run(App.new(application))
        0
      rescue LoadError => e
        out.puts "The interactive TUI requires the Charm Ruby gems (bubbletea, lipgloss)."
        out.puts "Install them, or use the CLI instead (`obsidian-import --help`)."
        out.puts "Details: #{e.message}"
        1
      end
    end
  end
end
