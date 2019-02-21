# frozen_string_literal: true

module Rails
  module Autoloaders # :nodoc:
    class << self
      include Enumerable

      def main
        if zeitwerk_enabled?
          @main ||= Zeitwerk::Loader.new.tap { |loader| loader.tag = "rails.main" }
        end
      end

      def once
        if zeitwerk_enabled?
          @once ||= Zeitwerk::Loader.new.tap { |loader| loader.tag = "rails.once" }
        end
      end

      def each
        if zeitwerk_enabled?
          yield main
          yield once
        end
      end

      def logger=(logger)
        callable_or_nil = logger.respond_to?(:debug) ? logger.method(:debug) : logger
        each { |loader| loader.logger = callable_or_nil }
      end

      def zeitwerk_enabled?
        Rails.configuration.autoloader == :zeitwerk
      end
    end
  end
end
