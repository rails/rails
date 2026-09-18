# frozen_string_literal: true

# :markup: markdown

require "digest"
require "base64"
require "fileutils"
require "json"
require "pathname"
require "active_support/core_ext/file/atomic"
require "active_support/isolated_execution_state"

module ActionView
  module ERBCompilationCache # :nodoc:
    FORMAT_VERSION = 2
    EXECUTION_KEY = :action_view_erb_compilation_cache_writer

    CorruptCacheError = Class.new(StandardError)
    UnsupportedImplementationError = Class.new(StandardError)

    class << self
      def fetch(implementation, source, options, enabled: true)
        return yield unless enabled && Ractor.current == Ractor.main

        unless key = cache_key(implementation, source, options)
          if current_writer
            raise UnsupportedImplementationError,
              "#{implementation.name || implementation.inspect} does not provide .erb_compilation_cache_key"
          end
          return yield
        end

        if writer = current_writer
          yield.tap { |compiled_source| writer.write(key, compiled_source) }
        elsif compiled_source = entries&.fetch(key, nil)
          compiled_source
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
        end
      end

      def clear
        @data_path = @entries = nil
      end

      def cache_path
        if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
          Pathname.new(Rails.root.to_s).join("tmp/cache/action_view/erb")
        end
      end

      def load!
        root = cache_path
        return unless root

        path = root.join("data.json").to_s
        return @entries if @data_path == path

        loaded_entries = load_entries(path)
        @data_path = path
        @entries = loaded_entries
      end

      private
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

        def entries
          @entries || load!
        end

        def load_entries(path)
          return {}.freeze unless File.file?(path)

          document = JSON.parse(File.binread(path))
          return {}.freeze unless document["version"] == FORMAT_VERSION

          entries = document["entries"]
          raise CorruptCacheError, "ERB compilation cache has no entries" unless entries.is_a?(Hash)

          entries.transform_values! { |entry| decode(entry) }
          Ractor.make_shareable(entries)
        rescue JSON::ParserError => error
          raise CorruptCacheError, "Invalid ERB compilation cache: #{error.message}"
        end

        def decode(entry)
          unless entry.is_a?(Hash) && entry["source"].is_a?(String) &&
              entry["encoding"].is_a?(String) && entry["digest"].is_a?(String)
            raise CorruptCacheError, "Invalid ERB compilation cache entry"
          end

          source = Base64.strict_decode64(entry["source"])
          digest = Digest::SHA256.hexdigest(source)
          unless digest == entry["digest"]
            raise CorruptCacheError, "ERB compilation cache digest mismatch"
          end

          source.force_encoding(entry["encoding"])
          source.freeze
        rescue ArgumentError => error
          raise CorruptCacheError, "Invalid ERB compilation cache entry: #{error.message}"
        end
    end

    class Writer # :nodoc:
      attr_reader :entries

      def initialize(path)
        @path = path
        @entries = {}
      end

      def write(key, source)
        bytes = source.b
        entry = {
          "source" => Base64.strict_encode64(bytes),
          "encoding" => source.encoding.name,
          "digest" => Digest::SHA256.hexdigest(bytes),
        }

        if existing = entries[key]
          unless existing == entry
            raise CorruptCacheError, "ERB compiler returned different output for the same cache key"
          end
        else
          entries[key] = entry
        end

        source
      end

      def publish
        data = JSON.generate("version" => FORMAT_VERSION, "entries" => entries.sort.to_h)

        FileUtils.mkdir_p(@path)
        File.atomic_write(@path.join("data.json")) do |file|
          file.write(data)
        end
      end
    end
  end
end
