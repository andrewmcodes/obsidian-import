# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for the {https://www.apple.com/app-store/ Apple App Store},
      # backed by the public iTunes Search API.
      #
      # Supports the +app+ object type. Requires no credentials.
      class Apple < Base
        object_types "app"
        source_name "Apple App Store"

        # @return [String]
        BASE_URL = "https://itunes.apple.com"

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          response = client.get("/search", params: {term: query, entity: "software", limit: 10, country: "US"})
          Array(response["results"]).map { |record| normalize(record: record) }
        end

        # @param id [String, Integer] the +trackId+
        # @return [Resource]
        # @raise [NotFoundError] when the App Store has no matching app
        def lookup(id:)
          response = client.get("/lookup", params: {id: id})
          record = Array(response["results"]).first
          raise NotFoundError, "#{source} has no app with id #{id}" if record.nil?

          normalize(record: record)
        end

        # Normalize a raw iTunes Search API result into a {Resource}.
        #
        # @param record [Hash] an iTunes Search API +results+ entry
        # @return [Resource]
        def normalize(record:)
          build(
            title: record["trackName"],
            subtype: "app",
            source_id: record["trackId"].to_s,
            description: record["description"],
            source_url: record["trackViewUrl"],
            metadata: {
              "seller" => record["sellerName"],
              "version" => record["version"],
              "genre" => record["primaryGenreName"],
              "bundle_id" => record["bundleId"],
              "image_url" => record["artworkUrl512"],
              "rating" => record["averageUserRating"],
              "price" => record["formattedPrice"]
            },
            tags: ["app"]
          )
        end

        private

        def base_url
          BASE_URL
        end
      end
    end
  end
end
