# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "pathname"
require "securerandom"
require "active_support/core_ext/file/atomic"
require "active_support/isolated_execution_state"

module ActionView
  module ERBCompilationCache # :nodoc:
    FORMAT_VERSION = 1
    EXECUTION_KEY = :action_view_erb_compilation_cache_writer

    CorruptCacheError = Class.new(StandardError)
    UnsupportedImplementationError = Class.new(StandardError)

    class << self
      def fetch(implementation, source, options, enabled: true)
        return yield unless enabled

        unless key = cache_key(implementation, source, options)
          if current_writer
            raise UnsupportedImplementationError,
              "#{implementation.name || implementation.inspect} does not provide .erb_compilation_cache_key"
          end
          return yield
        end

        if writer = current_writer
          yield.tap { |compiled_source| writer.write(key, compiled_source) }
        elsif entry = manifest&.fetch(key, nil)
          read(entry)
        else
          yield
        end
      end

      def build
        path = cache_path
        raise "Cannot build an ERB compilation cache without Rails.root" unless path

        writer = Writer.new(path)
        previous_writer = current_writer
        ActiveSupport::IsolatedExecutionState[EXECUTION_KEY] = writer

        begin
          yield
          writer.publish
          clear
          writer
        ensure
          ActiveSupport::IsolatedExecutionState[EXECUTION_KEY] = previous_writer
          writer.close
        end
      end

      def clear
        @manifest_path = @manifest = nil
      end

      private
        def cache_path
          Rails.root&.join("tmp/cache/action_view/erb") if defined?(Rails) && Rails.respond_to?(:root)
        end

        def current_writer
          ActiveSupport::IsolatedExecutionState[EXECUTION_KEY]
        end

        def cache_key(implementation, source, options)
          return unless implementation.respond_to?(:erb_compilation_cache_key)

          Digest::SHA256.hexdigest(JSON.generate([
            FORMAT_VERSION,
            implementation.erb_compilation_cache_key,
            Digest::SHA256.hexdigest(source.b),
            source.encoding.name,
            options,
          ]))
        rescue JSON::GeneratorError
          nil
        end

        def manifest
          root = cache_path
          return unless root

          path = root.join("manifest.json").to_s
          return @manifest if @manifest_path == path

          loaded_manifest = load_manifest(path)
          @manifest_path = path
          @manifest = loaded_manifest
        end

        def load_manifest(path)
          return unless File.file?(path)

          document = JSON.parse(File.binread(path))
          return unless document["version"] == FORMAT_VERSION

          entries = document["entries"]
          raise CorruptCacheError, "ERB compilation cache manifest has no entries" unless entries.is_a?(Hash)

          entries
        rescue JSON::ParserError => error
          raise CorruptCacheError, "Invalid ERB compilation cache manifest: #{error.message}"
        end

        def read(entry)
          unless entry.is_a?(Hash) && entry["path"].is_a?(String) &&
              entry["encoding"].is_a?(String) && entry["digest"].is_a?(String)
            raise CorruptCacheError, "Invalid ERB compilation cache entry"
          end

          path = cache_path.join(entry["path"])
          source = File.binread(path)
          digest = Digest::SHA256.hexdigest(source)
          unless digest == entry["digest"]
            raise CorruptCacheError, "ERB compilation cache digest mismatch for #{path}"
          end

          source.force_encoding(entry["encoding"])
        rescue Errno::ENOENT
          raise CorruptCacheError, "Missing ERB compilation cache entry #{path}"
        rescue ArgumentError => error
          raise CorruptCacheError, "Invalid ERB compilation cache encoding: #{error.message}"
        end
    end

    class Writer # :nodoc:
      attr_reader :entries

      def initialize(path)
        @path = path
        @staging_path = Pathname.new("#{path}.#{Process.pid}.#{SecureRandom.hex(6)}.tmp")
        @entries = {}
        FileUtils.mkdir_p(@staging_path.join("objects"))
      end

      def write(key, source)
        bytes = source.b
        digest = Digest::SHA256.hexdigest(bytes)
        relative_path = "objects/#{key}"
        entry = {
          "path" => relative_path,
          "encoding" => source.encoding.name,
          "digest" => digest,
        }

        if existing = entries[key]
          unless existing == entry
            raise CorruptCacheError, "ERB compiler returned different output for the same cache key"
          end
        else
          File.binwrite(@staging_path.join(relative_path), bytes)
          entries[key] = entry
        end

        source
      end

      def publish
        sorted_entries = entries.sort.to_h
        generation = Digest::SHA256.hexdigest(JSON.generate(sorted_entries))
        generation_path = @path.join("generations", generation)
        published_entries = sorted_entries.transform_values do |entry|
          entry.merge("path" => "generations/#{generation}/#{entry["path"]}")
        end
        manifest = JSON.generate("version" => FORMAT_VERSION, "entries" => published_entries)

        FileUtils.mkdir_p(generation_path.dirname)
        begin
          File.rename(@staging_path, generation_path)
        rescue Errno::EEXIST, Errno::ENOTEMPTY
          raise unless generation_path.directory?
        end

        File.atomic_write(@path.join("manifest.json")) do |file|
          file.write(manifest)
        end
      end

      def close
        FileUtils.rm_rf(@staging_path)
      end
    end
  end
end
