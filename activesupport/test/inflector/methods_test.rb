# frozen_string_literal: true

require "active_support/inflector/methods"
require "active_support/inflector/inflections"

module ActiveSupport
  module Inflector
    class MethodsTest < ActiveSupport::TestCase
      class DummyInflector
        include ActiveSupport::Inflector::Methods
        def inflections(_ = :en)
          ActiveSupport::Inflector::Inflections.new
        end
      end

      def test_basic
        inflector = DummyInflector.new

        assert_nothing_raised do
          inflector.pluralize("string")
          inflector.singularize("strings")
          inflector.camelize("a_string")
          inflector.underscore("AString")
        end
      end
    end
  end
end
