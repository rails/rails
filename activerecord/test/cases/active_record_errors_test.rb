# frozen_string_literal: true

require "cases/helper"

class ActiveRecordErrorsTest < ActiveRecord::TestCase
  class FakeAdapter
    def initialize(...)
    end
  end

  class AnotherFakeAdapter
    def initialize(...)
    end
  end

  class SubclassedFakeAdapter < FakeAdapter
  end

  def test_lookup
    ActiveRecord::Errors.register(->(e) { e.message == "0001" }, ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_equal ActiveRecord::StatementInvalid, ActiveRecord::Errors.lookup(adapter: FakeAdapter.new, exception: StandardError.new("0001"))
    assert ActiveRecord::Errors.exceptions_registered_for_adapter?(FakeAdapter.new)
  end

  def test_lookup_subclass
    ActiveRecord::Errors.register(->(e) { e.message == "0001" }, ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_equal ActiveRecord::StatementInvalid, ActiveRecord::Errors.lookup(adapter: SubclassedFakeAdapter.new, exception: StandardError.new("0001"))
    assert ActiveRecord::Errors.exceptions_registered_for_adapter?(SubclassedFakeAdapter.new)
  end

  def test_lookup_error_number_mismatch
    ActiveRecord::Errors.register(->(e) { e.message == "0001" }, ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_nil ActiveRecord::Errors.lookup(adapter: FakeAdapter.new, exception: StandardError.new("0002"))
  end

  def test_lookup_adapter_mismatch
    ActiveRecord::Errors.register(->(e) { e.message == "0001" }, ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_nil ActiveRecord::Errors.lookup(adapter: AnotherFakeAdapter.new, exception: StandardError.new("0001"))
  end

  def test_exceptions_registered_for_adapter
    assert_not ActiveRecord::Errors.exceptions_registered_for_adapter?(AnotherFakeAdapter.new)
  end
end
