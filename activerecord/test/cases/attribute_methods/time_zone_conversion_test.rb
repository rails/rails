require "cases/helper"
require 'models/developer'

module ActiveRecord
  module AttributeMethods
    class TimeZoneConversionTest < ActiveSupport::TestCase

      def test_invalid_date_doesnt_raise
        developer = Developer.new(updated_on: 'invalid')
        assert_equal nil, developer.updated_on
        assert_equal 'invalid', developer.updated_on_before_type_cast
      end
    end
  end
end
