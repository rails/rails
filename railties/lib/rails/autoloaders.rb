# frozen_string_literal: true

require "zeitwerk"

module Rails
  module Autoloaders # :nodoc:
    require_relative "autoloaders/inflector"

    class << self
      include Enumerable

      def main
        @main ||= Zeitwerk::Loader.new.tap do |loader|
          loader.tag = "rails.main"
          loader.inflector = Inflector
        end
      end

      def once
        @once ||= Zeitwerk::Loader.new.tap do |loader|
          loader.tag = "rails.once"
          loader.inflector = Inflector
        end
      end

      def each
        yield main
        yield once
      end

      def logger=(logger)
        each { |loader| loader.logger = logger }
      end

      def log!
        each(&:log!)
      end

      def zeitwerk_enabled?
        true
      end
    end
  end
end
