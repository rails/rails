# frozen_string_literal: true

module Rails
  # This is a private class, Rails.autoloaders provides the interface available
  # via a singleton instance.
  class Autoloaders # :nodoc:
    require_relative "autoloaders/inflector"

    class Any # :nodoc:
      def initialize(autoloaders)
        @autoloaders = autoloaders
      end

      def on_load(...)
        @autoloaders.each { |autoloader| autoloader.on_load(...) }
      end
    end

    include Enumerable

    attr_reader :main, :once, :any

    def initialize
      # This `require` delays loading the library on purpose.
      #
      # In Rails 7.0.0, railties/lib/rails.rb loaded Zeitwerk as a side-effect,
      # but a couple of edge cases related to Bundler and Bootsnap showed up.
      # They had to do with order of decoration of `Kernel#require`, something
      # the three of them do.
      #
      # Delaying this `require` up to this point is a convenient trade-off.
      require "zeitwerk"

      @main = Zeitwerk::Loader.new
      @main.tag = "rails.main"
      @main.inflector = Inflector

      @once = Zeitwerk::Loader.new
      @once.tag = "rails.once"
      @once.inflector = Inflector

      @any = Any.new([@main, @once])
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
