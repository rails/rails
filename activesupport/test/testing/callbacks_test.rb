# frozen_string_literal: true

require_relative "../abstract_unit"

module OtherAfterTeardown
  def after_teardown
    super

    @witness = true
  end
end

class AfterTeardownTest < ActiveSupport::TestCase
  include OtherAfterTeardown

  attr_writer :witness

  MyError = Class.new(StandardError)

  teardown do
    raise MyError, "Test raises an error, all after_teardown should still get called"
  end

  def after_teardown
    assert_changes -> { failures.count }, from: 0, to: 1 do
      super
    end

    assert_equal true, @witness
    failures.clear
  end

  def test_teardown_raise_but_all_after_teardown_method_are_called
    assert true
  end
end

class CallbackTest < ActiveSupport::TestCase
  test "does not override #send" do
    assert_not_includes self.class.ancestors, ActiveSupport::Testing::SetupAndTeardown::AroundCallbackSupport
  end
end

class AroundCallbackTest < ActiveSupport::TestCase
  class Client
    class_attribute :stubbed, default: false
  end

  around do |test, block|
    assert_not Client.stubbed

    Client.stubbed = true
    block.call
    Client.stubbed = false

    assert_not Client.stubbed
  end

  test "overrides #send for around callback support" do
    assert_includes self.class.ancestors, ActiveSupport::Testing::SetupAndTeardown::AroundCallbackSupport
  end

  test "changes from around hook are present" do
    assert Client.stubbed
  end

  test "around block when a test fails" do
    failing_test = Class.new(ActiveSupport::TestCase) do
      attr_reader :witness

      around do |_, test|
        test.call

        @witness = true
      end

      def self.name
        "FailingTest"
      end

      def test_fails
        flunk
      end
    end.new("test_fails")

    assert_nil failing_test.witness
    result = failing_test.run

    assert_not_predicate result, :passed?
    assert failing_test.witness
  end
end
