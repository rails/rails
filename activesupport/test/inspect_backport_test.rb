# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/inspect_backport"

class InspectBackportTest < ActiveSupport::TestCase
  test "inspect with no instance variables shows only class and address" do
    klass = Class.new do
      private
        def instance_variables_to_inspect
          [].freeze
        end
    end
    ActiveSupport::InspectBackport.apply(klass)

    obj = klass.new
    assert_match(/\A#<#{Regexp.escape(klass.inspect)}:0x[0-9a-f]+>\z/, obj.inspect)
  end

  test "inspect with instance variables shows them" do
    klass = Class.new do
      def initialize
        @name = "test"
        @count = 42
      end

      private
        def instance_variables_to_inspect
          [:@name, :@count].freeze
        end
    end
    ActiveSupport::InspectBackport.apply(klass)

    obj = klass.new
    assert_match(/@name="test"/, obj.inspect)
    assert_match(/@count=42/, obj.inspect)
  end

  test "inspect uses class name when available" do
    obj = NamedExample.new("hello")
    assert_match(/\A#<InspectBackportTest::NamedExample:0x[0-9a-f]+ @value="hello">\z/, obj.inspect)
  end

  test "inspect with unset instance variable shows nothing" do
    klass = Class.new do
      private
        def instance_variables_to_inspect
          [:@missing].freeze
        end
    end
    ActiveSupport::InspectBackport.apply(klass)

    obj = klass.new
    assert_no_match(/@missing=nil/, obj.inspect)
  end

  class NamedExample
    include ActiveSupport::InspectBackport

    def initialize(value)
      @value = value
    end

    private
      def instance_variables_to_inspect
        [:@value].freeze
      end
  end
end
