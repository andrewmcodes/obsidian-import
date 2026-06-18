# frozen_string_literal: true

module Obsidian
  module Import
    module TUI
      # Lip Gloss styling helpers for the TUI.
      #
      # Each helper returns a styled String. Lip Gloss automatically drops ANSI
      # styling when output is not a terminal, so these are safe to call in any
      # context.
      module Theme
        # Accent color (Charm purple).
        ACCENT = "63"
        # Muted/secondary color.
        MUTED = "245"
        # Error color.
        DANGER = "203"

        module_function

        # @param text [String]
        # @return [String] bold accent title.
        def title(text)
          style.bold(true).foreground(ACCENT).render(text)
        end

        # @param text [String]
        # @return [String] bold heading.
        def heading(text)
          style.bold(true).render(text)
        end

        # @param text [String]
        # @return [String] highlighted selected row.
        def selected(text)
          style.foreground(ACCENT).bold(true).render(text)
        end

        # @param text [String]
        # @return [String] dimmed/secondary text.
        def dim(text)
          style.foreground(MUTED).render(text.to_s)
        end

        # @param text [String]
        # @return [String] error-colored text.
        def error(text)
          style.foreground(DANGER).render("Error: #{text}")
        end

        # @return [String] the selection cursor marker.
        def cursor
          style.foreground(ACCENT).render("› ")
        end

        # @return [String] the search prompt marker.
        def prompt
          style.foreground(ACCENT).render("› ")
        end

        # @return [String] the blinking-ish input caret.
        def caret
          style.foreground(ACCENT).render("█")
        end

        # @return [Lipgloss::Style] a fresh style builder.
        def style
          Lipgloss::Style.new
        end
      end
    end
  end
end
