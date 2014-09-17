require 'cases/helper'

module ActiveRecord
  module Type
    class DateTest < ActiveRecord::TestCase
      test 'optional year while creating new date' do
        type = Type::Date.new
        current_date = ::Date.current.strftime('%m/%d')
        assert_equal ::Date.current, type.type_cast_from_user(current_date)
        assert_equal ::Date.parse('7/15'), type.type_cast_from_user('7/15')
      end
    end
  end
end
