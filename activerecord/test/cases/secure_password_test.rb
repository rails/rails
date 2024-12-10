# frozen_string_literal: true

require "cases/helper"
require "models/user"

class SecurePasswordTest < ActiveRecord::TestCase
  setup do
    # Speed up tests
    @original_min_cost = ActiveModel::SecurePassword.min_cost
    ActiveModel::SecurePassword.min_cost = true

    @user = User.create(password: "abc123", recovery_password: "123abc")
  end

  teardown do
    ActiveModel::SecurePassword.min_cost = @original_min_cost
  end

  test "authenticate_by authenticates when password is correct" do
    assert_equal @user, User.authenticate_by(token: @user.token, password: @user.password)
  end

  test "authenticate_by does not authenticate when password is incorrect" do
    assert_nil User.authenticate_by(token: @user.token, password: "wrong")
  end

  test "authenticate_by takes the same amount of time regardless of whether record is found" do
    # Warm-up (mostly to ensure the DB connection is established)
    User.authenticate_by(token: @user.token, password: @user.password)

    retry_flaky_test do
      # ActiveSupport::Benchmark.realtime returns fractional seconds. Thus, summing over 1000
      # iterations is equivalent to averaging over 1000 iterations and then
      # multiplying by 1000 to convert to milliseconds.
      found_average_time_in_ms = 1000.times.sum do
        ActiveSupport::Benchmark.realtime do
          User.authenticate_by(token: @user.token, password: @user.password)
        end
      end

      not_found_average_time_in_ms = 1000.times.sum do
        ActiveSupport::Benchmark.realtime do
          User.authenticate_by(token: "wrong", password: @user.password)
        end
      end

      assert_in_delta found_average_time_in_ms, not_found_average_time_in_ms, 0.5
    end
  end

  test "authenticate_by short circuits when password is nil" do
    assert_no_queries do
      assert_nil User.authenticate_by(token: @user.token, password: nil)
    end
  end

  test "authenticate_by short circuits when password is an empty string" do
    assert_no_queries do
      assert_nil User.authenticate_by(token: @user.token, password: "")
    end
  end

  test "authenticate_by finds record using multiple attributes" do
    assert_equal @user, User.authenticate_by(token: @user.token, auth_token: @user.auth_token, password: @user.password)
    assert_nil User.authenticate_by(token: @user.token, auth_token: "wrong", password: @user.password)
  end

  test "authenticate_by authenticates using multiple passwords" do
    assert_equal @user, User.authenticate_by(token: @user.token, password: @user.password, recovery_password: @user.recovery_password)
    assert_nil User.authenticate_by(token: @user.token, password: @user.password, recovery_password: "wrong")
  end

  test "authenticate_by requires at least one password" do
    assert_raises ArgumentError do
      User.authenticate_by(token: @user.token)
    end
  end

  test "authenticate_by requires at least one attribute" do
    assert_raises ArgumentError do
      User.authenticate_by(password: @user.password)
    end
  end

  test "authenticate_by accepts any object that implements to_h" do
    params = Enumerator.new { raise "must access via to_h" }

    assert_called_with(params, :to_h, [], returns: { token: @user.token, password: @user.password }) do
      assert_equal @user, User.authenticate_by(params)
    end

    assert_called_with(params, :to_h, [], returns: { token: "wrong", password: @user.password }) do
      assert_nil User.authenticate_by(params)
    end
  end

  private
    def retry_flaky_test(retry_count: 3)
      yield
    rescue Minitest::Assertion
      if retry_count > 0
        retry_count -= 1
        retry
      else
        raise
      end
    end
end
