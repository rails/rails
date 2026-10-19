# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/enumerable"

module ActiveRecord
  module AttributeMethods
    class ReadTest < ActiveRecord::TestCase
      FakeColumn = Struct.new(:name, :slot) do
        def type; :integer; end
      end

      FakeBuilder = Struct.new(:indexes)

      def setup
        @klass = Class.new(Class.new { def self.initialize_generated_modules; end }) do
          def self.superclass; Base; end
          def self.base_class?; true; end
          def self.abstract_class?; false; end
          def self.load_schema; end
          def self.schema_loaded?; true; end

          include ActiveRecord::AttributeMethods

          def self.attribute_names
            %w{ one two three }
          end

          def self.attribute_types
            {}
          end

          def self.primary_key
          end

          def self.columns
            attribute_names.each_with_index.map { |name, i| FakeColumn.new(name, i) }
          end

          def self.columns_hash
            columns.index_by(&:name)
          end

          def self.attributes_builder
            FakeBuilder.new(attribute_names.each_with_index.to_h)
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
