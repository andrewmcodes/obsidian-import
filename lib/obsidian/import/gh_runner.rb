# frozen_string_literal: true

require "open3"
require "json"

module Obsidian
  module Import
    # Runs GitHub API requests through the {https://cli.github.com gh CLI}
    # (+gh api+) when it is installed and authenticated.
    #
    # Preferring +gh api+ over a direct HTTP call means requests reuse the
    # user's existing gh credentials (higher rate limits, no token wiring) and
    # let gh handle authentication, the base URL, and headers. When gh is
    # unavailable, unauthenticated, or explicitly disabled, callers fall back to
    # a direct HTTP request.
    #
    # The CLI is always invoked with an argument array (never a shell string),
    # so user-supplied queries and identifiers cannot be interpreted by a shell.
    class GhRunner
      # Set this environment variable to a truthy value to force the direct
      # HTTP path even when gh is available.
      DISABLE_ENV = "OBSIDIAN_IMPORT_NO_GH"

      # @param executor [#call] receives an arg array (without the leading
      #   "gh") and returns +[stdout, stderr, status]+. Injectable for tests.
      def initialize(executor: method(:capture))
        @executor = executor
        @available = nil
      end

      # @return [Boolean] whether +gh api+ can be used (binary present,
      #   authenticated, and not disabled). Memoized.
      def available?
        @available = compute_available if @available.nil?
        !!@available
      end

      # Perform a GET request against the GitHub API via +gh api+.
      #
      # @param path [String] API path, e.g. "repos/rails/rails"
      # @param params [Hash] query parameters
      # @return [Object] the parsed JSON response
      # @raise [AdapterError] with the status mapped from gh's output
      def get(path, params = {})
        args = ["api", "-X", "GET", path]
        params.each { |key, value| args.push("-f", "#{key}=#{value}") }

        stdout, stderr, status = @executor.call(args)
        raise_for(stderr) unless status.success?
        parse(stdout)
      end

      private

      def compute_available
        return false if truthy?(ENV[DISABLE_ENV])
        _out, _err, status = @executor.call(["auth", "status"])
        status.success?
      rescue Errno::ENOENT
        false
      end

      def capture(args)
        Open3.capture3("gh", *args)
      end

      def parse(stdout)
        return {} if stdout.nil? || stdout.empty?
        JSON.parse(stdout)
      rescue JSON::ParserError => e
        raise ResponseError, "gh api returned a malformed response: #{e.message}"
      end

      def raise_for(stderr)
        code = stderr[/\(HTTP (\d+)\)/, 1]&.to_i
        case code
        when 401, 403
          raise AuthenticationError, "gh api: GitHub rejected the request (#{code})"
        when 404
          raise NotFoundError, "gh api: GitHub has no matching record (404)"
        when 429
          raise RateLimitError, "gh api: GitHub rate limit reached; try again later"
        else
          raise ResponseError, "gh api request failed: #{first_line(stderr)}"
        end
      end

      def first_line(text)
        text.to_s.lines.first&.strip.to_s
      end

      def truthy?(value)
        !value.nil? && !value.empty? && value != "0" && value.downcase != "false"
      end
    end
  end
end
