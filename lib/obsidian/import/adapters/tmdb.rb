# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for {https://www.themoviedb.org TMDb} (The Movie Database).
      #
      # Supports the +movie+ and +tv_show+ object types. The instance's
      # {#type} (set at construction) determines which endpoint is queried:
      # +tv_show+ hits the +/tv+ routes and +movie+ hits the +/movie+ routes.
      #
      # Requires an API key, sent as the +api_key+ query parameter on every
      # request. The HTTP client treats +api_key+ as sensitive, so it is
      # excluded from cache keys and redacted from error messages.
      class TMDb < Base
        object_types "movie", "tv_show"
        source_name "TMDb"

        # @return [String]
        BASE_URL = "https://api.themoviedb.org/3"

        # @return [String] base URL for poster images.
        IMAGE_BASE_URL = "https://image.tmdb.org/t/p/w500"

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          records = client.get("search/#{media}", params: {query: query})
          Array(records["results"]).map { |record| normalize(record: record) }
        end

        # @param id [String] the TMDb identifier
        # @return [Resource]
        def lookup(id:)
          normalize(record: client.get("#{media}/#{id}"))
        end

        # @param record [Hash] a TMDb movie or TV record
        # @return [Resource]
        def normalize(record:)
          build(
            type: @type,
            subtype: nil,
            title: record["title"] || record["name"],
            source_id: record["id"].to_s,
            description: record["overview"],
            source_url: "https://www.themoviedb.org/#{media}/#{record["id"]}",
            metadata: {
              "release_date" => record["release_date"] || record["first_air_date"],
              "rating" => record["vote_average"],
              "poster_url" => poster_url(record["poster_path"]),
              "genres" => Array(record["genres"]).map { |genre| genre["name"] },
              "status" => record["status"],
              "homepage_url" => record["homepage"]
            },
            tags: [@type]
          )
        end

        private

        # @return [String] the API path segment for the current type.
        def media
          (@type == "tv_show") ? "tv" : "movie"
        end

        def poster_url(path)
          path ? "#{IMAGE_BASE_URL}#{path}" : nil
        end

        def base_url
          BASE_URL
        end

        def request_params
          {"api_key" => require_credential!(:tmdb)}
        end
      end
    end
  end
end
