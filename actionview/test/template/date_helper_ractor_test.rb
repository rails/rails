# frozen_string_literal: true

require "abstract_unit"

class DateHelperRactorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  if defined?(Ractor) && RUBY_VERSION >= "4.0"
    test "select_datetime renders inside a non-main Ractor" do
      datetime = Time.utc(2004, 6, 4, 15, 16, 35)
      options = { order: [:year, :month, :day], use_month_names: Date::MONTHNAMES }

      rendered_in_ractor = Ractor.new(datetime, options) do |time, opts|
        Object.new.extend(ActionView::Helpers::DateHelper).select_datetime(time, opts)
      end

      rendered = Object.new.extend(ActionView::Helpers::DateHelper).select_datetime(datetime, options)

      assert_equal rendered, rendered_in_ractor.value
    end

    test "DateTimeSelector datetime readers are callable from a non-main Ractor" do
      values = Ractor.new do
        time = ActionView::Helpers::DateTimeSelector.new(Time.utc(2004, 6, 4, 15, 16, 35), {})
        hash = ActionView::Helpers::DateTimeSelector.new({ year: 2004, month: 6, day: 4 }, {})
        [
          %i(sec min hour day month year).map { |reader| time.send(reader) },
          %i(day month year).map { |reader| hash.send(reader) },
        ]
      end.value

      assert_equal [[35, 16, 15, 4, 6, 2004], [4, 6, 2004]], values
    end
  end
end
