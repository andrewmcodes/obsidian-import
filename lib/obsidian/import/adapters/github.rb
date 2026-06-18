# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for {https://github.com GitHub} repositories.
      #
      # Supports the +github_repo+ object type. When the {https://cli.github.com
      # gh CLI} is installed and authenticated, requests are made through
      # +gh api+ (reusing the user's gh credentials); otherwise they fall back
      # to a direct HTTP request. For the HTTP path, authentication is optional:
      # a token from the +github+ API key or +GITHUB_TOKEN+ is sent as a bearer
      # token to raise rate limits, but unauthenticated requests work too.
      class GitHub < Base
        object_types "github_repo"
        source_name "GitHub"

        # @return [String]
        BASE_URL = "https://api.github.com"

        # @param type [String, nil]
        # @param gh [GhRunner, nil] injectable gh runner (defaults to a real one)
        # @param kwargs [Hash] forwarded to {Base#initialize}
        def initialize(gh: nil, **kwargs)
          super(**kwargs)
          @gh = gh
        end

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          response = fetch("search/repositories", q: query, per_page: 10)
          Array(response["items"]).map { |record| normalize(record: record) }
        end

        # @param id [String] the "owner/repo" full name
        # @return [Resource]
        def lookup(id:)
          normalize(record: fetch("repos/#{id}"))
        end

        # @param record [Hash] a GitHub repository object
        # @return [Resource]
        def normalize(record:)
          build(
            title: record["full_name"],
            source_id: record["full_name"],
            source_url: record["html_url"],
            description: record["description"],
            metadata: {
              "stars" => record["stargazers_count"],
              "forks" => record["forks_count"],
              "language" => record["language"],
              "license" => record.dig("license", "spdx_id"),
              "topics" => Array(record["topics"]),
              "homepage_url" => record["homepage"],
              "owner" => record.dig("owner", "login")
            },
            tags: ["github"]
          )
        end

        private

        # Fetch a GitHub API endpoint, preferring +gh api+ when available.
        #
        # @param path [String]
        # @param params [Hash]
        # @return [Object] parsed JSON
        def fetch(path, **params)
          if gh.available?
            cache.fetch(cache_key(path, params)) { gh.get(path, params) }
          else
            client.get(path, params: params)
          end
        end

        # @return [GhRunner]
        def gh
          @gh ||= GhRunner.new
        end

        def cache_key(path, params)
          query = params.sort.map { |key, value| "#{key}=#{value}" }.join("&")
          "github:gh:#{path}?#{query}"
        end

        def base_url
          BASE_URL
        end

        # @return [Hash] default headers, including a bearer token when one is
        #   configured. Used only on the direct-HTTP fallback path.
        def request_headers
          headers = {
            "Accept" => "application/vnd.github+json",
            "User-Agent" => "obsidian-import",
            "X-GitHub-Api-Version" => "2022-11-28"
          }
          token = config.api_key("github")
          headers["Authorization"] = "Bearer #{token}" if token
          headers
        end
      end
    end
  end
end
