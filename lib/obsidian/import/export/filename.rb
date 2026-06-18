# frozen_string_literal: true

module Obsidian
  module Import
    # Obsidian-output concerns: slugs, frontmatter, templates, and vault writes.
    module Export
      # Generates safe, deterministic note filenames from titles.
      #
      # Rules (per ADR-001):
      #
      # 1. Convert to lowercase.
      # 2. Replace spaces and other separators with hyphens.
      # 3. Remove characters that are invalid on common filesystems.
      # 4. Preserve ASCII letters, numbers, and hyphens.
      # 5. Append numeric suffixes to resolve collisions.
      module Filename
        module_function

        # Convert an arbitrary title into a filesystem-safe slug.
        #
        # @example
        #   Filename.slugify("Ruby on Rails")   #=> "ruby-on-rails"
        #   Filename.slugify("@changesets/cli")  #=> "changesets-cli"
        #
        # @param title [String]
        # @return [String] the slug (without extension)
        def slugify(title)
          slug = title.to_s.downcase
          slug = slug.gsub(/[^a-z0-9]+/, "-")
          slug = slug.squeeze("-")
          slug = slug.delete_prefix("-").delete_suffix("-")
          slug.empty? ? "untitled" : slug
        end

        # Resolve a non-colliding filename within +dir+.
        #
        # If +slug+.+ext+ is free it is returned; otherwise +slug+-2.+ext+,
        # +slug+-3.+ext+, and so on, are tried. An optional secondary extension
        # (e.g. "gem") produces software-style names such as +rubocop.gem.md+
        # and collisions such as +rubocop-2.gem.md+.
        #
        # @param dir [String] target directory (need not exist yet)
        # @param slug [String] base slug, without extension
        # @param ext [String] file extension, without the dot
        # @param secondary [String, nil] optional secondary extension
        # @return [String] a filename (basename only) that does not yet exist
        def unique(dir, slug, ext: "md", secondary: nil)
          sec = (secondary.nil? || secondary.to_s.empty?) ? "" : ".#{secondary}"
          candidate = "#{slug}#{sec}.#{ext}"
          return candidate unless File.exist?(File.join(dir, candidate))

          counter = 2
          loop do
            candidate = "#{slug}-#{counter}#{sec}.#{ext}"
            break unless File.exist?(File.join(dir, candidate))
            counter += 1
          end
          candidate
        end
      end
    end
  end
end
