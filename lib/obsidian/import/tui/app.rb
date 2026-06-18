# frozen_string_literal: true

module Obsidian
  module Import
    module TUI
      # The Bubble Tea model implementing the whole interactive flow as a small
      # state machine across four screens: Home (pick a type), Search (type a
      # query), Results (navigate matches), and Preview (inspect + act).
      #
      # The model is deliberately self-contained: list navigation and text
      # input are handled directly from {Bubbletea::KeyMessage}s, and styling
      # goes through {Theme}. All data operations are delegated to
      # {Application}, so the TUI never talks to adapters or the vault directly.
      class App
        include Bubbletea::Model

        # @param application [Application]
        def initialize(application)
          @app = application
          @screen = :home
          @types = @app.types
          @cursor = 0
          @query = +""
          @results = []
          @selected = nil
          @status = nil
          @error = nil
        end

        # @return [Array(App, nil)] the Elm-architecture init tuple.
        def init
          [self, nil]
        end

        # Handle a message and return the next [model, command] tuple.
        #
        # @param message [Bubbletea::Message]
        # @return [Array(App, Object)]
        def update(message)
          return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)
          return [self, Bubbletea.quit] if message.to_s == "ctrl+c"

          case @screen
          when :home then update_home(message)
          when :search then update_search(message)
          when :results then update_results(message)
          when :preview then update_preview(message)
          else [self, nil]
          end
        end

        # @return [String] the rendered view for the current screen.
        def view
          body =
            case @screen
            when :home then render_home
            when :search then render_search
            when :results then render_results
            when :preview then render_preview
            else ""
            end

          [Theme.title("obsidian-import"), body, footer].join("\n")
        end

        private

        # --- Home -----------------------------------------------------------

        def update_home(message)
          return [self, nil] if @types.empty?
          if message.up?
            @cursor = (@cursor - 1) % @types.length
          elsif message.down?
            @cursor = (@cursor + 1) % @types.length
          elsif message.enter?
            enter_search
          end
          [self, nil]
        end

        def render_home
          lines = ["Select an object type:", ""]
          @types.each_with_index do |info, index|
            marker = (index == @cursor) ? Theme.cursor : "  "
            label = info[:requires_key] ? "#{info[:label]} (key)" : info[:label]
            text = "#{marker}#{label}"
            lines << ((index == @cursor) ? Theme.selected(text) : text)
          end
          lines.join("\n")
        end

        # --- Search ---------------------------------------------------------

        def enter_search
          @current_type = @types[@cursor]
          @screen = :search
          @query = +""
          @results = []
          @error = nil
          @status = nil
        end

        def update_search(message)
          if message.esc?
            @screen = :home
          elsif message.enter?
            perform_search
          elsif message.backspace?
            @query.chop!
          elsif message.space?
            @query << " "
          elsif printable?(message)
            @query << message.char.to_s
          end
          [self, nil]
        end

        def perform_search
          return if @query.strip.empty?

          @error = nil
          @results = @app.search(@current_type[:type], @query.strip)
          if @results.empty?
            @status = "No results."
          else
            @cursor = 0
            @screen = :results
          end
        rescue Obsidian::Import::Error => e
          @error = e.message
        end

        def render_search
          lines = ["Search #{@current_type[:label]}:", "", "  #{Theme.prompt}#{@query}#{Theme.caret}"]
          lines << "" << Theme.error(@error) if @error
          lines << "" << Theme.dim(@status) if @status
          lines.join("\n")
        end

        # --- Results --------------------------------------------------------

        def update_results(message)
          if message.esc? || message.to_s == "/"
            @screen = :search
          elsif @results.empty?
            # nothing to navigate
          elsif message.up?
            @cursor = (@cursor - 1) % @results.length
          elsif message.down?
            @cursor = (@cursor + 1) % @results.length
          elsif message.enter?
            @selected = @results[@cursor]
            @status = nil
            @screen = :preview
          end
          [self, nil]
        end

        def render_results
          lines = ["Results for #{@query.strip.inspect}:", ""]
          @results.each_with_index do |resource, index|
            marker = (index == @cursor) ? Theme.cursor : "  "
            text = "#{marker}#{resource.title}"
            lines << ((index == @cursor) ? Theme.selected(text) : text)
          end
          lines.join("\n")
        end

        # --- Preview --------------------------------------------------------

        def update_preview(message)
          if message.esc?
            @screen = :results
            @status = nil
          else
            case message.to_s
            when "c" then create_note
            when "y" then copy(@app.markdown(@selected), "Markdown")
            when "f" then copy(@app.frontmatter(@selected), "frontmatter")
            when "o" then open_source
            end
          end
          [self, nil]
        end

        def render_preview
          r = @selected
          lines = [Theme.heading(r.title)]
          lines << Theme.dim(r.description) if r.description
          lines << ""
          lines << "type:    #{r.type}"
          lines << "source:  #{r.source}"
          lines << "url:     #{r.source_url}" if r.source_url
          r.metadata.first(6).each { |key, value| lines << "#{key}: #{Array(value).join(", ")}" }
          lines << "" << Theme.dim(@status) if @status
          lines << "" << Theme.error(@error) if @error
          lines.join("\n")
        end

        def create_note
          @error = nil
          path = @app.export(@selected)
          @status = "Created note: #{path}"
        rescue Obsidian::Import::Error => e
          @error = e.message
        end

        def copy(text, label)
          if system("command -v pbcopy > /dev/null 2>&1")
            IO.popen("pbcopy", "w") { |io| io.write(text) }
            @status = "Copied #{label} to clipboard."
          else
            @status = "Clipboard unavailable (no pbcopy)."
          end
        rescue SystemCallError
          @status = "Clipboard unavailable."
        end

        def open_source
          if @selected.source_url && system("command -v open > /dev/null 2>&1")
            system("open", @selected.source_url)
            @status = "Opened #{@selected.source_url}"
          else
            @status = "No source URL to open."
          end
        end

        # --- Shared ---------------------------------------------------------

        def footer
          hint =
            case @screen
            when :home then "↑/↓ navigate · enter select · ctrl+c quit"
            when :search then "type to search · enter run · esc back · ctrl+c quit"
            when :results then "↑/↓ navigate · enter preview · / edit search · esc back"
            when :preview then "c create · y copy md · f copy frontmatter · o open · esc back"
            else ""
            end
          "\n#{Theme.dim(hint)}"
        end

        def printable?(message)
          message.runes? && message.char.to_s.length == 1 && !message.ctrl?
        end
      end
    end
  end
end
