# frozen_string_literal: true

require "faraday"
require "json"
require "uri"
require "digest"

module Obsidian
  module Import
    # HTTP plumbing shared by all adapters.
    module HTTP
      # A thin, JSON-oriented wrapper over Faraday.
      #
      # Responsibilities:
      #
      # - Issue GET requests against a base URL with default headers/params
      # - Parse JSON responses using the standard library
      # - Map transport and status errors onto the library's error hierarchy
      # - Cache successful responses (keyed without secrets)
      # - Redact sensitive query parameters from any error message
      #
      # Credentials passed via headers or params are never logged or cached.
      class Client
        # Query-parameter names whose values must never appear in errors or
        # cache keys are matched by this pattern (e.g. +api_key+, +access_token+,
        # +client_secret+, +password+, +auth+). Matching by substring rather
        # than a fixed list means a new secret-bearing parameter is redacted by
        # default rather than leaking.
        SENSITIVE_PARAM_PATTERN = /key|token|secret|password|auth|signature/i

        # @param base_url [String] the API base URL
        # @param headers [Hash] default headers sent with every request
        # @param params [Hash] default query params sent with every request
        # @param cache [Cache, nil] cache store, or nil to disable caching
        # @param ttl [Integer, nil] cache TTL override in seconds
        # @param source [String] short adapter/source name used in error text
        def initialize(base_url:, headers: {}, params: {}, cache: Cache.new, ttl: nil, source: "http")
          @base_url = base_url
          @default_headers = headers
          @default_params = stringify(params)
          @cache = cache
          @ttl = ttl
          @source = source
        end

        # Perform a GET request and return the parsed JSON body.
        #
        # @param path [String] request path relative to the base URL
        # @param params [Hash] additional query parameters
        # @return [Hash, Array] the parsed JSON response
        # @raise [AdapterError] on transport, status, or parse failures
        def get(path, params: {})
          request(:get, path, params: params)
        end

        # Perform a POST with a JSON body and return the parsed JSON response.
        #
        # Like {#get}, successful responses are cached; the cache key includes a
        # digest of the body so different queries do not collide. Used for APIs
        # whose query interface is a POST (e.g. the VS Code Marketplace).
        #
        # @param path [String] request path relative to the base URL
        # @param body [Object] a JSON-serializable request body
        # @param params [Hash] additional query parameters
        # @return [Hash, Array] the parsed JSON response
        # @raise [AdapterError] on transport, status, or parse failures
        def post(path, body:, params: {})
          request(:post, path, params: params, body: body)
        end

        private

        def request(method, path, params:, body: nil)
          # A leading slash would make Faraday discard the base URL's path, so
          # requests are always relative to the (trailing-slash) base.
          path = path.to_s.sub(%r{\A/+}, "")
          merged = @default_params.merge(stringify(params))
          key = cache_key(method, path, merged, body)

          if @cache
            cached = @cache.read(key, ttl: effective_ttl)
            return cached unless cached.nil?
          end

          result = perform(method, path, merged, body)
          @cache&.write(key, result)
          result
        end

        def perform(method, path, params, body)
          response = dispatch(method, path, params, body)
          handle(response, path, params)
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
          raise NetworkError, "Network error contacting #{@source}: #{e.message}"
        end

        def dispatch(method, path, params, body)
          case method
          when :get
            connection.get(path, params)
          when :post
            connection.post(path) do |req|
              req.params.update(params) unless params.empty?
              req.headers["Content-Type"] = "application/json"
              req.body = JSON.generate(body)
            end
          end
        end

        def handle(response, path, params)
          case response.status
          when 200..299
            parse(response.body)
          when 401, 403
            raise AuthenticationError, "#{@source} rejected the request (#{response.status}) for #{redact(path, params)}"
          when 404
            raise NotFoundError, "#{@source} has no record for #{redact(path, params)}"
          when 429
            raise RateLimitError, "#{@source} rate limit reached; try again later"
          else
            raise ResponseError, "#{@source} returned an unexpected status #{response.status} for #{redact(path, params)}"
          end
        end

        def parse(body)
          return {} if body.nil? || body.empty?
          JSON.parse(body)
        rescue JSON::ParserError => e
          raise ResponseError, "#{@source} returned a malformed response: #{e.message}"
        end

        def connection
          base = @base_url.end_with?("/") ? @base_url : "#{@base_url}/"
          @connection ||= Faraday.new(url: base, headers: @default_headers) do |conn|
            conn.options.timeout = 15
            conn.options.open_timeout = 5
            conn.adapter Faraday.default_adapter
          end
        end

        def cache_key(method, path, params, body)
          safe = params.reject { |k, _| sensitive?(k) }
          query = safe.sort.map { |k, v| "#{k}=#{v}" }.join("&")
          digest = body.nil? ? "" : ":#{Digest::SHA256.hexdigest(JSON.generate(body))}"
          "#{@source}:#{method}:#{@base_url}#{path}?#{query}#{digest}"
        end

        def redact(path, params)
          safe = params.map do |k, v|
            sensitive?(k) ? [k, "[REDACTED]"] : [k, v]
          end.to_h
          query = safe.map { |k, v| "#{k}=#{v}" }.join("&")
          query.empty? ? path : "#{path}?#{query}"
        end

        def sensitive?(key)
          SENSITIVE_PARAM_PATTERN.match?(key.to_s)
        end

        def effective_ttl
          @ttl || Obsidian::Import.configuration.cache_ttl
        end

        def stringify(hash)
          (hash || {}).each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
        end
      end
    end
  end
end
