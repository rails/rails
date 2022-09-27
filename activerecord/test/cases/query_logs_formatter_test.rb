# frozen_string_literal: true

require "cases/helper"

class QueryLogsFormatter < ActiveRecord::TestCase
  def test_factory_invalid_formatter
    assert_raises(ArgumentError) do
      ActiveRecord::QueryLogs::FormatterFactory.from_symbol(:non_existing_formatter)
    end
    end

  def test_sqlcommenter_key_value_separator
    formatter = ActiveRecord::QueryLogs::FormatterFactory.from_symbol(:sqlcommenter)
    assert_equal("=", formatter.key_value_separator)
  end

  def test_sqlcommenter_format_value
    formatter = ActiveRecord::QueryLogs::FormatterFactory.from_symbol(:sqlcommenter)
    assert_equal("'Joe\\'s Crab Shack'", formatter.format_value("Joe's Crab Shack"))
  end

  def test_sqlcommenter_format_value_string_coercible
    formatter = ActiveRecord::QueryLogs::FormatterFactory.from_symbol(:sqlcommenter)
    assert_equal("'1234'", formatter.format_value(1234))
  end
end
