# frozen_string_literal: true

require "erb"

module Obsidian
  module Import
    module Export
      # Renders the Markdown body of a note from an ERB template chosen by the
      # resource's object type.
      module Template
        # Object types that use the shared software-object template.
        SOFTWARE_TYPES = %w[gem npm_package github_repo app].freeze

        # Directory holding the bundled +.md.erb+ templates.
        TEMPLATE_DIR = File.expand_path("../templates", __dir__)

        module_function

        # @param resource [Resource]
        # @return [String] the rendered Markdown body (no frontmatter).
        def body_for(resource)
          erb = ERB.new(source_for(resource.type), trim_mode: "-")
          erb.result(Context.new(resource).binding_for)
        end

        # @param type [String]
        # @return [String] the template name for a type.
        def template_name(type)
          SOFTWARE_TYPES.include?(type.to_s) ? "software" : "default"
        end

        # @api private
        def source_for(type)
          File.read(File.join(TEMPLATE_DIR, "#{template_name(type)}.md.erb"))
        end

        # Isolated binding context exposed to templates. Only +resource+ is
        # available, keeping templates side-effect free.
        class Context
          # @param resource [Resource]
          def initialize(resource)
            @resource = resource
          end

          # @return [Resource]
          attr_reader :resource

          # @return [Binding] a binding exposing +resource+ to ERB.
          def binding_for
            binding
          end
        end
      end
    end
  end
end
