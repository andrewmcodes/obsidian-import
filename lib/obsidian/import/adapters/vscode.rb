# frozen_string_literal: true

module Obsidian
  module Import
    module Adapters
      # Adapter for {https://marketplace.visualstudio.com Visual Studio
      # Marketplace} extensions (the canonical source for VS Code extensions).
      #
      # Supports the +vscode_extension+ object type. Requires no credentials.
      #
      # The Marketplace gallery exposes a single +extensionquery+ POST endpoint
      # (the same one the VS Code client uses) for both search and lookup, so
      # this adapter posts a filter document and reads +results[0].extensions+.
      class VSCode < Base
        object_types "vscode_extension"
        source_name "Visual Studio Marketplace"

        # @return [String]
        BASE_URL = "https://marketplace.visualstudio.com/_apis/public/gallery"

        # Accept header pinning the gallery API version.
        API_VERSION = "application/json;api-version=3.0-preview.1"

        # Restricts results to extensions targeting VS Code.
        TARGET = "Microsoft.VisualStudio.Code"

        # Marketplace filter type codes.
        FILTER_TARGET = 8
        FILTER_EXTENSION_NAME = 7
        FILTER_SEARCH_TEXT = 10

        # Response flags: versions + files + categories/tags + version
        # properties + asset URIs + statistics + latest version only.
        FLAGS = 919

        # Asset type for an extension's icon within a version's file list.
        ICON_ASSET = "Microsoft.VisualStudio.Services.Icons.Default"

        # @param query [String]
        # @return [Array<Resource>]
        def search(query:)
          query_extensions(filter_type: FILTER_SEARCH_TEXT, value: query, page_size: 10)
            .map { |record| normalize(record: record) }
        end

        # @param id [String] the "publisher.name" extension identifier
        # @return [Resource]
        def lookup(id:)
          record = query_extensions(filter_type: FILTER_EXTENSION_NAME, value: id, page_size: 1).first
          raise NotFoundError, "Visual Studio Marketplace has no extension '#{id}'" if record.nil?
          normalize(record: record)
        end

        # @param record [Hash] a Marketplace extension object
        # @return [Resource]
        def normalize(record:)
          publisher = record["publisher"] || {}
          name = [publisher["publisherName"], record["extensionName"]].compact.join(".")
          build(
            title: record["displayName"] || record["extensionName"],
            subtype: "extension",
            source_id: name,
            source_url: "https://marketplace.visualstudio.com/items?itemName=#{name}",
            description: record["shortDescription"],
            metadata: {
              "publisher" => publisher["displayName"] || publisher["publisherName"],
              "version" => latest_version(record),
              "installs" => statistic(record, "install"),
              "rating" => statistic(record, "averagerating"),
              "categories" => Array(record["categories"]),
              "extension_tags" => Array(record["tags"]),
              "icon_url" => icon_url(record)
            },
            tags: ["vscode", "extension"]
          )
        end

        private

        def query_extensions(filter_type:, value:, page_size:)
          body = {
            filters: [{
              criteria: [
                {filterType: FILTER_TARGET, value: TARGET},
                {filterType: filter_type, value: value}
              ],
              pageNumber: 1,
              pageSize: page_size,
              sortBy: 0,
              sortOrder: 0
            }],
            flags: FLAGS
          }
          response = client.post("/extensionquery", body: body)
          Array(response.dig("results", 0, "extensions"))
        end

        def latest_version(record)
          Array(record["versions"]).first&.fetch("version", nil)
        end

        def statistic(record, name)
          Array(record["statistics"]).find { |stat| stat["statisticName"] == name }&.fetch("value", nil)
        end

        def icon_url(record)
          files = Array(Array(record["versions"]).first&.fetch("files", nil))
          files.find { |file| file["assetType"] == ICON_ASSET }&.fetch("source", nil)
        end

        def base_url
          BASE_URL
        end

        def request_headers
          {"Accept" => API_VERSION}
        end
      end
    end
  end
end
