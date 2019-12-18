# frozen_string_literal: true

require "active_support/dependencies/zeitwerk_integration"

module Rails
  module Autoloaders # :nodoc:
    class << self
      include Enumerable

      def main
        if zeitwerk_enabled?
          @main ||= Zeitwerk::Loader.new.tap do |loader|
            loader.tag = "rails.main"
            loader.inflector = ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector
          end
        end
      end

      def once
        if zeitwerk_enabled?
          @once ||= Zeitwerk::Loader.new.tap do |loader|
            loader.tag = "rails.once"
            loader.inflector = ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector
          end
        end
      end

      def each
        if zeitwerk_enabled?
          yield main
          yield once
        end
      end

      def logger=(logger)
        each { |loader| loader.logger = logger }
      end

      def log!
        each(&:log!)
      end

      def zeitwerk_enabled?
        Rails.configuration.autoloader == :zeitwerk
      end
    end
  end
end
