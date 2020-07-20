# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/enumerable"

module ActiveRecord
  module AttributeMethods
    class ReadTest < ActiveRecord::TestCase
      FakeColumn = Struct.new(:name) do
        def type; :integer; end
      end

      def setup
        @klass = Class.new(Class.new { def self.initialize_generated_modules; end }) do
          def self.superclass; Base; end
          def self.base_class?; true; end

          include ActiveRecord::AttributeMethods

          def self.attribute_names
            %w{ one two three }
          end

          def self.primary_key
          end

          def self.columns
            attribute_names.map { FakeColumn.new(name) }
          end

          def self.columns_hash
            attribute_names.index_with { |name|
              FakeColumn.new(name)
            }
          end
        end
      end

      def test_define_attribute_methods
        instance = @klass.new

        @klass.attribute_names.each do |name|
          assert_not_includes instance.methods.map(&:to_s), name
        end

        @klass.define_attribute_methods

        @klass.attribute_names.each do |name|
          assert_includes instance.methods.map(&:to_s), name, "#{name} is not defined"
        end
      end

      def test_attribute_methods_generated?
        assert_not @klass.method_defined?(:one)
        @klass.define_attribute_methods
        assert @klass.method_defined?(:one)
      end
    end
  end
end
