# frozen_string_literal: true

# :markup: markdown

require "digest"
require "fileutils"
require "json"
require "pathname"
require "active_support/core_ext/file/atomic"

module ActionView
  module ERBCompilationCache # :nodoc:
    FORMAT_VERSION = 2

    UnsupportedImplementationError = Class.new(StandardError)

    class << self
      def fetch(implementation, source, options, enabled: true)
        return yield unless enabled && Ractor.current == Ractor.main

        unless key = cache_key(implementation, source, options)
          if @writing
            raise UnsupportedImplementationError,
              "#{implementation.name || implementation.inspect} does not provide .erb_compilation_cache_key"
          end
          return yield
        end

        if @writing
          @writing[key] = yield
        elsif compiled_source = load!&.fetch(key, nil)
          compiled_source
        else
          yield
        end
      end

      def build
        path = cache_path
        raise "Cannot build an ERB compilation cache without Rails.root" unless path

        @writing = {}
        yield

        FileUtils.mkdir_p(path)
        File.atomic_write(path.join("data.dump")) do |file|
          Marshal.dump(@writing.sort.to_h, file)
        end

        @writing
      ensure
        @writing = nil
      end

      def clear
        @entries = nil
      end

      def cache_path
        if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
          Pathname.new(Rails.root.to_s).join("tmp/cache/action_view/erb")
        end
      end

      def load!
        root = cache_path
        return unless root
        return @entries if @entries

        path = root.join("data.dump")
        return @entries = {}.freeze unless File.file?(path)

        @entries = Ractor.make_shareable(Marshal.load(File.binread(path), freeze: true))
      end

      private
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
    end
  end
end
