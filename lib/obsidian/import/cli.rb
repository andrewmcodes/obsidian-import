# frozen_string_literal: true

require "optparse"

module Obsidian
  module Import
    # Command-line interface for automation and scripting.
    #
    # The CLI is a thin layer over {Application}: it parses arguments, invokes
    # the facade, and formats the result. All library errors are rendered as
    # friendly messages (never raw backtraces), and the process exit status
    # reflects success (0) or failure (1).
    #
    # @example
    #   Obsidian::Import::CLI.start(["search", "gem", "view_component"])
    class CLI
      # Usage banner shown by +help+ and on invalid invocations.
      BANNER = <<~TEXT
        obsidian-import — import metadata into an Obsidian vault

        Usage:
          obsidian-import                  # launch the interactive TUI
          obsidian-import types
          obsidian-import search <type> <query>
          obsidian-import show <type> <id> [--frontmatter]
          obsidian-import export <type> <id> [--vault PATH] [--folder NAME]
          obsidian-import config init [--force]

        Options:
          -h, --help       Show this help
          -v, --version    Show the version
      TEXT

      # Run the CLI and return a process exit status.
      #
      # @param argv [Array<String>]
      # @param out [IO] standard output stream
      # @param err [IO] standard error stream
      # @return [Integer] 0 on success, 1 on failure
      def self.start(argv, out: $stdout, err: $stderr)
        new(out: out, err: err).run(argv)
      end

      # @param out [IO]
      # @param err [IO]
      # @param application [Application]
      def initialize(out: $stdout, err: $stderr, application: Application.new)
        @out = out
        @err = err
        @app = application
      end

      # @param argv [Array<String>]
      # @return [Integer] exit status
      def run(argv)
        argv = argv.dup
        command = argv.shift

        case command
        when nil then launch_tui
        when "tui" then launch_tui
        when "types" then cmd_types(argv)
        when "search" then cmd_search(argv)
        when "show" then cmd_show(argv)
        when "export" then cmd_export(argv)
        when "config" then cmd_config(argv)
        when "-v", "--version" then print_version
        when "-h", "--help", "help" then print_help
        else
          @err.puts "Unknown command: #{command}"
          @err.puts BANNER
          1
        end
      rescue Obsidian::Import::Error => e
        @err.puts "Error: #{e.message}"
        1
      end

      private

      def cmd_types(_argv)
        @out.puts "Available object types:"
        @app.types.each do |info|
          suffix = info[:requires_key] ? "  (requires API key)" : ""
          @out.puts format("  %-14s %s%s", info[:type], info[:label], suffix)
        end
        0
      end

      def cmd_search(argv)
        type = argv.shift
        query = argv.join(" ")
        return usage_error("search requires <type> and <query>") if type.nil? || query.empty?

        results = @app.search(type, query)
        if results.empty?
          @out.puts "No results for #{query.inspect}."
          return 0
        end

        results.each_with_index do |resource, index|
          @out.puts format("%2d. %s", index + 1, resource.title)
          @out.puts "    #{truncate(resource.description)}" if resource.description
          @out.puts "    #{resource.source_url}" if resource.source_url
        end
        0
      end

      def cmd_show(argv)
        frontmatter_only = false
        parser = OptionParser.new do |o|
          o.on("--frontmatter") { frontmatter_only = true }
        end
        rest = parser.parse(argv)
        type, id = rest
        return usage_error("show requires <type> and <id>") if type.nil? || id.nil?

        resource = @app.lookup(type, id)
        @out.puts(frontmatter_only ? @app.frontmatter(resource) : @app.markdown(resource))
        0
      end

      def cmd_export(argv)
        vault = nil
        folder = nil
        parser = OptionParser.new do |o|
          o.on("--vault PATH") { |v| vault = v }
          o.on("--folder NAME") { |v| folder = v }
        end
        rest = parser.parse(argv)
        type, id = rest
        return usage_error("export requires <type> and <id>") if type.nil? || id.nil?

        resource = @app.lookup(type, id)
        path = @app.export(resource, vault_path: vault || @app.config.vault_path, folder: folder)
        @out.puts "Created note: #{path}"
        0
      end

      def cmd_config(argv)
        action = argv.shift
        return usage_error("config requires a subcommand (init)") unless action == "init"

        force = argv.include?("--force")
        path = Configuration.init!(force: force)
        @out.puts "Wrote config to #{path}"
        0
      end

      def launch_tui
        TUI.start(application: @app, out: @out)
      end

      def print_version
        @out.puts "obsidian-import #{Obsidian::Import::VERSION}"
        0
      end

      def print_help
        @out.puts BANNER
        0
      end

      def usage_error(message)
        @err.puts "Error: #{message}"
        1
      end

      def truncate(text, limit: 100)
        clean = text.to_s.tr("\n", " ").strip
        (clean.length > limit) ? "#{clean[0, limit - 1]}…" : clean
      end
    end
  end
end
