# frozen_string_literal: true

require "active_support"
require "active_support/test_case"
require "active_support/testing/autorun"
require "rails/railtie/configuration"

module RailtiesTest
  class DynamicOptionsTest < ActiveSupport::TestCase
    setup do
      @config = Rails::Railtie::Configuration.dup.new
      @config.class.class_variable_set(:@@options, {})
    end

    test "arbitrary keys can be set, reset, and read" do
      @config.foo = 1
      assert_equal 1, @config.foo

      @config.foo = 2
      assert_equal 2, @config.foo
    end

    test "raises NoMethodError if the key is unset and the method does not exist" do
      assert_raises(NoMethodError) do
        @config.unset_key
      end
    end

    test "raises NoMethodError with an informative message if assigning to an existing method" do
      error = assert_raises(NoMethodError) do
        @config.eager_load_namespaces = 1
      end

      assert_match(/Cannot assign to `eager_load_namespaces`, it is a configuration method/, error.message)
    end
  end
end
