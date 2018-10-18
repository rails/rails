# frozen_string_literal: true

require "cases/helper"
require "models/admin"
require "models/admin/user"
require "models/admin/account"
require "pp"

class FilterAttributesTest < ActiveRecord::TestCase
  fixtures :"admin/users", :"admin/accounts"

  setup do
    @previous_filter_attributes = ActiveRecord::Base.filter_attributes
    ActiveRecord::Base.filter_attributes = [:name]
  end

  teardown do
    ActiveRecord::Base.filter_attributes = @previous_filter_attributes
  end

  test "filter_attributes" do
    Admin::User.all.each do |user|
      assert_includes user.inspect, "name: [FILTERED]"
      assert_equal 1, user.inspect.scan("[FILTERED]").length
    end

    Admin::Account.all.each do |account|
      assert_includes account.inspect, "name: [FILTERED]"
      assert_equal 1, account.inspect.scan("[FILTERED]").length
    end
  end

  test "filter_attributes could be overwritten by models" do
    Admin::Account.all.each do |account|
      assert_includes account.inspect, "name: [FILTERED]"
      assert_equal 1, account.inspect.scan("[FILTERED]").length
    end

    begin
      previous_account_filter_attributes = Admin::Account.filter_attributes
      Admin::Account.filter_attributes = []

      # Above changes should not impact other models
      Admin::User.all.each do |user|
        assert_includes user.inspect, "name: [FILTERED]"
        assert_equal 1, user.inspect.scan("[FILTERED]").length
      end

      Admin::Account.all.each do |account|
        assert_not_includes account.inspect, "name: [FILTERED]"
        assert_equal 0, account.inspect.scan("[FILTERED]").length
      end
    ensure
      Admin::Account.filter_attributes = previous_account_filter_attributes
    end
  end

  test "filter_attributes should not filter nil value" do
    account = Admin::Account.new

    assert_includes account.inspect, "name: nil"
    assert_not_includes account.inspect, "name: [FILTERED]"
    assert_equal 0, account.inspect.scan("[FILTERED]").length
  end

  test "filter_attributes on pretty_print" do
    user = admin_users(:david)
    actual = "".dup
    PP.pp(user, StringIO.new(actual))

    assert_includes actual, "name: [FILTERED]"
    assert_equal 1, actual.scan("[FILTERED]").length
  end

  test "filter_attributes on pretty_print should not filter nil value" do
    user = Admin::User.new
    actual = "".dup
    PP.pp(user, StringIO.new(actual))

    assert_includes actual, "name: nil"
    assert_not_includes actual, "name: [FILTERED]"
    assert_equal 0, actual.scan("[FILTERED]").length
  end
end
