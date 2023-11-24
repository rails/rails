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


    def error_number(exception)
      exception.message.reverse
    end
  end

  class SubclassedFakeAdapter < FakeAdapter
  end

  def setup
    ActiveRecord::Errors.registry = {}
  end

  def test_lookup_proc
    ActiveRecord::Errors.register(->(e) { e.message == "0001" }, ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_equal ActiveRecord::StatementInvalid, ActiveRecord::Errors.lookup(adapter: FakeAdapter.new, exception: StandardError.new("0001"))
  end

  def test_lookup_string_message
    ActiveRecord::Errors.register("0001", ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_equal ActiveRecord::StatementInvalid, ActiveRecord::Errors.lookup(adapter: FakeAdapter.new, exception: StandardError.new("0001"))
  end

  def test_lookup_string_error_code
    ActiveRecord::Errors.register("1000", ActiveRecord::StatementInvalid, adapter: AnotherFakeAdapter)

    assert_equal ActiveRecord::StatementInvalid, ActiveRecord::Errors.lookup(adapter: AnotherFakeAdapter.new, exception: StandardError.new("0001"))
  end

  def test_lookup_regexp_message
    ActiveRecord::Errors.register(/...1/, ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_equal ActiveRecord::StatementInvalid, ActiveRecord::Errors.lookup(adapter: FakeAdapter.new, exception: StandardError.new("0001"))
  end

  def test_lookup_regexp_error_code
    ActiveRecord::Errors.register(/1.../, ActiveRecord::StatementInvalid, adapter: AnotherFakeAdapter)

    assert_equal ActiveRecord::StatementInvalid, ActiveRecord::Errors.lookup(adapter: AnotherFakeAdapter.new, exception: StandardError.new("0001"))
  end

  def test_lookup_subclass
    ActiveRecord::Errors.register(->(e) { e.message == "0001" }, ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_equal ActiveRecord::StatementInvalid, ActiveRecord::Errors.lookup(adapter: SubclassedFakeAdapter.new, exception: StandardError.new("0001"))
  end

  def test_lookup_error_number_mismatch
    ActiveRecord::Errors.register(->(e) { e.message == "0001" }, ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_nil ActiveRecord::Errors.lookup(adapter: FakeAdapter.new, exception: StandardError.new("0002"))
  end

  def test_lookup_adapter_mismatch
    ActiveRecord::Errors.register(->(e) { e.message == "0001" }, ActiveRecord::StatementInvalid, adapter: FakeAdapter)

    assert_nil ActiveRecord::Errors.lookup(adapter: AnotherFakeAdapter.new, exception: StandardError.new("0001"))
  end
end
