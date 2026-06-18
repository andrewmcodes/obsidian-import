# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for the {https://openlibrary.org Open Library} catalog.
      #
      # Supports the +book+ object type. Requires no credentials.
      class OpenLibrary < Base
        object_types "book"
        source_name "Open Library"

        # @return [String]
        BASE_URL = "https://openlibrary.org"

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          response = client.get("/search.json", params: {q: query, limit: 10})
          Array(response&.dig("docs")).map { |record| normalize(record: record) }
        end

        # @param id [String] an Open Library work key, e.g. +"OL123W"+
        # @return [Resource]
        def lookup(id:)
          normalize(record: client.get("/works/#{id}.json"))
        end

        # Normalize a record from either the search-doc shape or the
        # work-lookup shape into a {Resource}.
        #
        # @param record [Hash] an Open Library search doc or work object
        # @return [Resource]
        def normalize(record:)
          id = work_id(record)
          build(
            title: record["title"],
            subtype: nil,
            source_id: id,
            source_url: "https://openlibrary.org/works/#{id}",
            description: description(record["description"]),
            metadata: {
              "authors" => Array(record["author_name"]),
              "first_published" => record["first_publish_year"],
              "cover_url" => cover_url(record["cover_i"]),
              "isbn" => Array(record["isbn"]).first,
              "subjects" => Array(record["subject"] || record["subjects"])
            },
            tags: ["book"]
          )
        end

        private

        # Strip the +/works/+ prefix from a work key, sourcing it from either
        # the search-doc or work-lookup shape.
        #
        # @param record [Hash]
        # @return [String, nil]
        def work_id(record)
          key = record["key"]
          key&.sub(%r{\A/works/}, "")
        end

        # Flatten a description that may be a String, a Hash carrying a
        # +"value"+ key, or absent.
        #
        # @param value [String, Hash, nil]
        # @return [String, nil]
        def description(value)
          case value
          when Hash then value["value"]
          else value
          end
        end

        # @param cover_id [Integer, nil]
        # @return [String, nil]
        def cover_url(cover_id)
          return nil unless cover_id
          "https://covers.openlibrary.org/b/id/#{cover_id}-L.jpg"
        end

        def base_url
          BASE_URL
        end
      end
    end
  end
end
