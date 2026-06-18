# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for the {https://www.listennotes.com Listen Notes} podcast
      # database (API v2).
      #
      # Supports the +podcast+ object type. Requires a Listen Notes API key,
      # sent as the +X-ListenAPI-Key+ request header.
      class ListenNotes < Base
        object_types "podcast"
        source_name "Listen Notes"

        # @return [String]
        BASE_URL = "https://listen-api.listennotes.com/api/v2"

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          response = client.get("/search", params: {q: query, type: "podcast"})
          Array(response["results"]).map { |record| normalize(record: record) }
        end

        # @param id [String] the Listen Notes podcast id
        # @return [Resource]
        def lookup(id:)
          normalize(record: client.get("/podcasts/#{id}"))
        end

        # @param record [Hash] a Listen Notes podcast object, tolerant of both
        #   search (+..._original+) and lookup field names.
        # @return [Resource]
        def normalize(record:)
          build(
            title: record["title"] || record["title_original"],
            source_id: record["id"],
            source_url: record["listennotes_url"] || record["website"],
            description: record["description"] || record["description_original"],
            metadata: {
              "publisher" => record["publisher"] || record["publisher_original"],
              "website" => record["website"],
              "total_episodes" => record["total_episodes"],
              "image_url" => record["image"]
            },
            tags: ["podcast"]
          )
        end

        private

        def base_url
          BASE_URL
        end

        # @return [Hash] the credentialed request headers.
        # @raise [MissingCredentialError] when no API key is configured.
        def request_headers
          {"X-ListenAPI-Key" => require_credential!(:listen_notes)}
        end
      end
    end
  end
end
