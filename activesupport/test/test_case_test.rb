# frozen_string_literal: true

require_relative "abstract_unit"

class AssertionsTest < ActiveSupport::TestCase
  def setup
    @object = Class.new do
      attr_accessor :num
      def increment
        self.num += 1
      end

      def decrement
        self.num -= 1
      end
    end.new
    @object.num = 0
  end

  def test_assert_not
    assert_equal true, assert_not(nil)
    assert_equal true, assert_not(false)

    e = assert_raises(Minitest::Assertion) { assert_not true }
    assert_equal "Expected true to be nil or false", e.message

    e = assert_raises(Minitest::Assertion) { assert_not true, "custom" }
    assert_equal "custom", e.message
  end

  def test_assert_no_difference_pass
    assert_no_difference "@object.num" do
      # ...
    end
  end

  def test_assert_no_difference_fail
    error = assert_raises(Minitest::Assertion) do
      assert_no_difference "@object.num" do
        @object.increment
      end
    end
    assert_equal "\"@object.num\" didn't change by 0.\nExpected: 0\n  Actual: 1", error.message
  end

  def test_assert_no_difference_with_message_fail
    error = assert_raises(Minitest::Assertion) do
      assert_no_difference "@object.num", "Object Changed" do
        @object.increment
      end
    end
    assert_equal "Object Changed.\n\"@object.num\" didn't change by 0.\nExpected: 0\n  Actual: 1", error.message
  end

  def test_assert_no_difference_with_multiple_expressions_pass
    another_object = @object.dup
    assert_no_difference ["@object.num", -> { another_object.num }] do
      # ...
    end
  end

  def test_assert_no_difference_with_multiple_expressions_fail
    another_object = @object.dup
    assert_raises(Minitest::Assertion) do
      assert_no_difference ["@object.num", -> { another_object.num }], "Another Object Changed" do
        another_object.increment
      end
    end
  end

  def test_assert_difference
    assert_difference "@object.num", +1 do
      @object.increment
    end
  end

  def test_assert_difference_retval
    incremented = assert_difference "@object.num", +1 do
      @object.increment
    end

    assert_equal incremented, 1
  end

  def test_assert_difference_with_implicit_difference
    assert_difference "@object.num" do
      @object.increment
    end
  end

  def test_arbitrary_expression
    assert_difference "@object.num + 1", +2 do
      @object.increment
      @object.increment
    end
  end

  def test_negative_differences
    assert_difference "@object.num", -1 do
      @object.decrement
    end
  end

  def test_expression_is_evaluated_in_the_appropriate_scope
    silence_warnings do
      local_scope = "foo"
      _ = local_scope  # to suppress unused variable warning
      assert_difference("local_scope; @object.num") { @object.increment }
    end
  end

  def test_array_of_expressions
    assert_difference [ "@object.num", "@object.num + 1" ], +1 do
      @object.increment
    end
  end

  def test_array_of_expressions_identify_failure
    assert_raises(Minitest::Assertion) do
      assert_difference ["@object.num", "1 + 1"] do
        @object.increment
      end
    end
  end

  def test_array_of_expressions_identify_failure_when_message_provided
    assert_raises(Minitest::Assertion) do
      assert_difference ["@object.num", "1 + 1"], 1, "something went wrong" do
        @object.increment
      end
    end
  end

  def test_hash_of_expressions
    assert_difference "@object.num" => 1, "@object.num + 1" => 1 do
      @object.increment
    end
  end

  def test_hash_of_expressions_with_message
    error = assert_raises Minitest::Assertion do
      assert_difference({ "@object.num" => 0 }, "Object Changed") do
        @object.increment
      end
    end
    assert_equal "Object Changed.\n\"@object.num\" didn't change by 0.\nExpected: 0\n  Actual: 1", error.message
  end

  def test_hash_of_lambda_expressions
    assert_difference -> { @object.num } => 1, -> { @object.num + 1 } => 1 do
      @object.increment
    end
  end

  def test_hash_of_expressions_identify_failure
    assert_raises(Minitest::Assertion) do
      assert_difference "@object.num" => 1, "1 + 1" => 1 do
        @object.increment
      end
    end
  end

  def test_assert_changes_pass
    assert_changes "@object.num" do
      @object.increment
    end
  end

  def test_assert_changes_pass_with_lambda
    assert_changes -> { @object.num } do
      @object.increment
    end
  end

  def test_assert_changes_with_from_option
    assert_changes "@object.num", from: 0 do
      @object.increment
    end
  end

  def test_assert_changes_with_from_option_with_wrong_value
    assert_raises Minitest::Assertion do
      assert_changes "@object.num", from: -1 do
        @object.increment
      end
    end
  end

  def test_assert_changes_with_from_option_with_nil
    error = assert_raises Minitest::Assertion do
      assert_changes "@object.num", from: nil do
        @object.increment
      end
    end
    assert_equal "Expected change from nil", error.message
  end

  def test_assert_changes_with_to_option
    assert_changes "@object.num", to: 1 do
      @object.increment
    end
  end

  def test_assert_changes_with_to_option_but_no_change_has_special_message
    error = assert_raises Minitest::Assertion do
      assert_changes "@object.num", to: 0 do
        # no changes
      end
    end

    assert_equal "\"@object.num\" didn't change. It was already 0.\nExpected 0 to not be equal to 0.", error.message
  end

  def test_assert_changes_with_wrong_to_option
    assert_raises Minitest::Assertion do
      assert_changes "@object.num", to: 2 do
        @object.increment
      end
    end
  end

  def test_assert_changes_with_from_option_and_to_option
    assert_changes "@object.num", from: 0, to: 1 do
      @object.increment
    end
  end

  def test_assert_changes_with_from_and_to_options_and_wrong_to_value
    assert_raises Minitest::Assertion do
      assert_changes "@object.num", from: 0, to: 2 do
        @object.increment
      end
    end
  end

  def test_assert_changes_works_with_any_object
    # Silences: instance variable @new_object not initialized.
    retval = silence_warnings do
      assert_changes :@new_object, from: nil, to: 42 do
        @new_object = 42
      end
    end

    assert_equal 42, retval
  end

  def test_assert_changes_works_with_nil
    oldval = @object

    retval = assert_changes :@object, from: oldval, to: nil do
      @object = nil
    end

    assert_nil retval
  end

  def test_assert_changes_with_to_and_case_operator
    token = nil

    assert_changes -> { token }, to: /\w{32}/ do
      token = SecureRandom.hex
    end
  end

  def test_assert_changes_with_to_and_from_and_case_operator
    token = SecureRandom.hex

    assert_changes -> { token }, from: /\w{32}/, to: /\w{32}/ do
      token = SecureRandom.hex
    end
  end

  def test_assert_changes_with_message
    error = assert_raises Minitest::Assertion do
      assert_changes "@object.num", "@object.num should be 1", to: 1 do
        @object.decrement
      end
    end

    assert_equal "@object.num should be 1.\nExpected change to 1\n", error.message
  end

  def test_assert_no_changes_pass
    assert_no_changes "@object.num" do
      # ...
    end
  end

  def test_assert_no_changes_with_message
    error = assert_raises Minitest::Assertion do
      assert_no_changes "@object.num", "@object.num should not change" do
        @object.increment
      end
    end

    assert_equal "@object.num should not change.\n\"@object.num\" changed.\nExpected: 0\n  Actual: 1", error.message
  end

  def test_assert_no_changes_with_long_string_wont_output_everything
    lines = "HEY\n" * 12

    error = assert_raises Minitest::Assertion do
      assert_no_changes "lines" do
        lines += "HEY ALSO\n"
      end
    end

    assert_match <<~output, error.message
      "lines" changed.
      --- expected
      +++ actual
      @@ -10,4 +10,5 @@
       HEY
       HEY
       HEY
      +HEY ALSO
       "
    output
  end
end

# Setup and teardown callbacks.
class SetupAndTeardownTest < ActiveSupport::TestCase
  setup :reset_callback_record, :foo
  teardown :foo, :sentinel

  def test_inherited_setup_callbacks
    assert_equal [:reset_callback_record, :foo], self.class._setup_callbacks.map(&:raw_filter)
    assert_equal [:foo], @called_back
    assert_equal [:foo, :sentinel], self.class._teardown_callbacks.map(&:raw_filter)
  end

  def setup
  end

  def teardown
  end

  private
    def reset_callback_record
      @called_back = []
    end

    def foo
      @called_back << :foo
    end

    def sentinel
      assert_equal [:foo], @called_back
    end
end

class SubclassSetupAndTeardownTest < SetupAndTeardownTest
  setup :bar
  teardown :bar

  def test_inherited_setup_callbacks
    assert_equal [:reset_callback_record, :foo, :bar], self.class._setup_callbacks.map(&:raw_filter)
    assert_equal [:foo, :bar], @called_back
    assert_equal [:foo, :sentinel, :bar], self.class._teardown_callbacks.map(&:raw_filter)
  end

  private
    def bar
      @called_back << :bar
    end

    def sentinel
      assert_equal [:foo, :bar, :bar], @called_back
    end
end

class TestCaseTaggedLoggingTest < ActiveSupport::TestCase
  def before_setup
    require "stringio"
    @out = StringIO.new
    self.tagged_logger = ActiveSupport::TaggedLogging.new(Logger.new(@out))
    super
  end

  def test_logs_tagged_with_current_test_case
    assert_match "#{self.class}: #{name}\n", @out.string
  end
end

class TestOrderTest < ActiveSupport::TestCase
  def setup
    @original_test_order = ActiveSupport::TestCase.test_order
  end

  def teardown
    ActiveSupport::TestCase.test_order = @original_test_order
  end

  def test_defaults_to_random
    ActiveSupport::TestCase.test_order = nil

    assert_equal :random, ActiveSupport::TestCase.test_order

    assert_equal :random, ActiveSupport.test_order
  end

  def test_test_order_is_global
    ActiveSupport::TestCase.test_order = :sorted

    assert_equal :sorted, ActiveSupport.test_order
    assert_equal :sorted, ActiveSupport::TestCase.test_order
    assert_equal :sorted, self.class.test_order
    assert_equal :sorted, Class.new(ActiveSupport::TestCase).test_order

    ActiveSupport.test_order = :random

    assert_equal :random, ActiveSupport.test_order
    assert_equal :random, ActiveSupport::TestCase.test_order
    assert_equal :random, self.class.test_order
    assert_equal :random, Class.new(ActiveSupport::TestCase).test_order
  end
end
