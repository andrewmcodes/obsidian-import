# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for {https://github.com GitHub} repositories.
      #
      # Supports the +github_repo+ object type. Authentication is optional: when
      # a token is configured (via the +github+ API key or the +GITHUB_TOKEN+
      # environment variable) it is sent as a bearer token to raise rate limits,
      # but unauthenticated requests work too.
      class GitHub < Base
        object_types "github_repo"
        source_name "GitHub"

        # @return [String]
        BASE_URL = "https://api.github.com"

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          response = client.get("/search/repositories", params: {q: query, per_page: 10})
          Array(response["items"]).map { |record| normalize(record: record) }
        end

        # @param id [String] the "owner/repo" full name
        # @return [Resource]
        def lookup(id:)
          normalize(record: client.get("/repos/#{id}"))
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

        def base_url
          BASE_URL
        end

        # @return [Hash] default headers, including a bearer token when one is
        #   configured.
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
