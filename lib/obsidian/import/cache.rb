# frozen_string_literal: true

require "digest"
require "json"
require "fileutils"

module Obsidian
  module Import
    # A small file-based cache for API responses.
    #
    # Entries are keyed by a SHA-256 digest of the logical cache key, stored as
    # JSON on disk under the cache directory, and expire after a configurable
    # TTL. Only response payloads are ever stored — never credentials,
    # +Authorization+ headers, or other secrets.
    #
    # @example Memoize an expensive lookup
    #   cache.fetch("rubygems:gem:rails") { adapter.lookup(id: "rails") }
    class Cache
      # @return [String] absolute path to the cache directory.
      attr_reader :dir

      # @return [Integer] default time-to-live, in seconds.
      attr_reader :ttl

      # @param dir [String] cache directory (defaults to the XDG cache home)
      # @param ttl [Integer] default TTL in seconds
      def initialize(dir: self.class.default_dir, ttl: 86_400)
        @dir = dir
        @ttl = ttl
      end

      # @return [String] the default cache directory, honoring +XDG_CACHE_HOME+.
      def self.default_dir
        base = ENV["XDG_CACHE_HOME"]
        base = File.expand_path("~/.cache") if base.nil? || base.empty?
        File.join(base, "obsidian-import")
      end

      # Read a cached value or compute, store, and return it.
      #
      # @param key [String] logical cache key
      # @param ttl [Integer] override TTL for this entry
      # @yieldreturn [Object] JSON-serializable value to cache on a miss
      # @return [Object] the cached or freshly computed value
      def fetch(key, ttl: @ttl)
        existing = read(key, ttl: ttl)
        return existing unless existing.nil?

        value = yield
        write(key, value)
        value
      end

      # @param key [String] logical cache key
      # @param ttl [Integer] freshness window in seconds
      # @return [Object, nil] the cached value, or nil if missing/expired
      def read(key, ttl: @ttl)
        envelope = JSON.parse(File.read(path_for(key)))
        return nil unless fresh?(envelope, ttl)
        envelope["value"]
      rescue Errno::ENOENT, JSON::ParserError
        nil
      end

      # Persist a value under +key+.
      #
      # @param key [String] logical cache key
      # @param value [Object] JSON-serializable value
      # @return [Object] the stored value
      def write(key, value)
        FileUtils.mkdir_p(dir)
        envelope = {"stored_at" => now, "value" => value}
        path = path_for(key)
        # Write to a unique temp file and atomically rename into place so a
        # concurrent reader/writer or a crash mid-write never sees a partial
        # file at the canonical path.
        tmp = "#{path}.#{Process.pid}.#{object_id}.tmp"
        File.write(tmp, JSON.generate(envelope))
        File.rename(tmp, path)
        value
      end

      # Remove all cached entries.
      #
      # @return [void]
      def clear
        FileUtils.rm_rf(dir)
      end

      private

      def path_for(key)
        File.join(dir, "#{Digest::SHA256.hexdigest(key.to_s)}.json")
      end

      def fresh?(envelope, ttl)
        stored_at = envelope["stored_at"]
        return false unless stored_at.is_a?(Numeric)
        (now - stored_at) < ttl
      end

      def now
        Time.now.to_i
      end
    end
  end
end
