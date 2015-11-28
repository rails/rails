require "cases/helper"
require 'thread'

module ActiveRecord
  module AttributeMethods
    class QueryTest < ActiveRecord::TestCase

      def setup
        @product = Class.new(ActiveRecord::Base)
        @product.table_name = 'products'
      end

      def test_check_for_attribute_value
        [0.5, -0.5, '0.5', -3, 3].each do |val|
          @product.create(price: val)
          product = @product.where(price: val).select('price as dummy_price').first
          assert_equal product.dummy_price?, true
        end
        @product.create(price: 0)
        product = @product.where(price: 0).select('price as dummy_price').first
        assert_equal product.dummy_price?, false
      end
    end
  end
end
