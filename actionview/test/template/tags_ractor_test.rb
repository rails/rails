# frozen_string_literal: true

require "abstract_unit"

class TagsRactorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  if defined?(Ractor) && RUBY_VERSION >= "4.0"
    test "field_type is computed at load time and readable from a non-main Ractor" do
      field_types = Ractor.new do
        [
          ActionView::Helpers::Tags::TextField.field_type,          # class body memoization
          ActionView::Helpers::Tags::SearchField.field_type,        # direct subclass: inherited
          ActionView::Helpers::Tags::RangeField.field_type,         # indirect subclass: inherited
          ActionView::Helpers::Tags::DatetimeLocalField.field_type, # custom: class body instance variable
        ]
      end.value

      assert_equal ["text", "search", "range", "datetime-local"], field_types
    end
  end
end
