# frozen_string_literal: true

module AsyncHelper
  private
    def assert_async_equal(expected, async_result)
      message = "Expected to return an ActiveRecord::Promise, got: #{async_result.inspect}"
      assert ActiveRecord::Promise === async_result, message

      if expected.nil?
        assert_nil async_result.value
      else
        assert_equal expected, async_result.value
      end
    end
end
