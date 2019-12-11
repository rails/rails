# frozen_string_literal: true

# in case active_support/inflector is required without the rest of active_support
require "active_support/inflector/inflections"
require "active_support/inflector/transliterate"
require "active_support/inflector/methods"

require "active_support/inflector/default_inflections"
require "active_support/core_ext/string/inflections"

module ActiveSupport
  module Inflector
    extend Transliterate
    extend Methods

    # Yields a singleton instance of Inflector::Inflections so you can specify
    # additional inflector rules. If passed an optional locale, rules for other
    # languages can be specified. If not specified, defaults to <tt>:en</tt>.
    # Only rules for English are provided.
    #
    #   ActiveSupport::Inflector.inflections(:en) do |inflect|
    #     inflect.uncountable 'rails'
    #   end
    def self.inflections(locale = :en)
      if block_given?
        yield Inflections.instance(locale)
      else
        Inflections.instance(locale)
      end
    end

    DefaultInflections.apply(inflections)
  end
end
