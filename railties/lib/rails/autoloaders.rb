# frozen_string_literal: true

module Rails
  class Autoloaders # :nodoc:
    require_relative "autoloaders/inflector"

    include Enumerable

    attr_reader :main, :once

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
