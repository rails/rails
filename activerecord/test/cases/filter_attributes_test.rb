# frozen_string_literal: true

require "cases/helper"
require "models/admin"
require "models/admin/user"
require "models/admin/account"
require "models/user"
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

  test "filter_attributes affects attribute_for_inspect" do
    Admin::User.all.each do |user|
      assert_equal "[FILTERED]", user.attribute_for_inspect(:name)
    end
  end

  test "string filter_attributes perform partial match" do
    ActiveRecord::Base.filter_attributes = ["n"]
    Admin::Account.all.each do |account|
      assert_includes account.inspect, "name: [FILTERED]"
      assert_equal 1, account.inspect.scan("[FILTERED]").length
    end
  end

  test "regex filter_attributes are accepted" do
    ActiveRecord::Base.filter_attributes = [/\An\z/]
    account = Admin::Account.find_by(name: "37signals")
    assert_includes account.inspect, 'name: "37signals"'
    assert_equal 0, account.inspect.scan("[FILTERED]").length

    ActiveRecord::Base.filter_attributes = [/\An/]
    account = Admin::Account.find_by(name: "37signals")
    assert_includes account.reload.inspect, "name: [FILTERED]"
    assert_equal 1, account.inspect.scan("[FILTERED]").length
  end

  test "proc filter_attributes are accepted" do
    ActiveRecord::Base.filter_attributes = [ lambda { |key, value| value.reverse! if key == "name" } ]
    account = Admin::Account.find_by(name: "37signals")
    assert_includes account.inspect, 'name: "slangis73"'
  end

  test "proc filter_attributes don't prevent marshal dump" do
    ActiveRecord::Base.filter_attributes = [ lambda { |key, value| value.reverse! if key == "name" } ]
    account = Admin::Account.new(id: 123, name: "37signals")
    account.inspect
    assert_equal account, Marshal.load(Marshal.dump(account))
  end

  test "filter_attributes could be overwritten by models" do
    Admin::Account.all.each do |account|
      assert_includes account.inspect, "name: [FILTERED]"
      assert_equal 1, account.inspect.scan("[FILTERED]").length
    end

    begin
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
      Admin::Account.remove_instance_variable(:@filter_attributes)
    end
  end

  test "filter_attributes should not filter nil value" do
    account = Admin::Account.new

    assert_includes account.inspect, "name: nil"
    assert_not_includes account.inspect, "name: [FILTERED]"
    assert_equal 0, account.inspect.scan("[FILTERED]").length
  end

  test "filter_attributes should handle [FILTERED] value properly" do
    User.filter_attributes = ["auth"]
    user = User.new(token: "[FILTERED]", auth_token: "[FILTERED]")

    assert_includes user.inspect, "auth_token: [FILTERED]"
    assert_includes user.inspect, 'token: "[FILTERED]"'
  ensure
    User.remove_instance_variable(:@filter_attributes)
  end

  test "filter_attributes on pretty_print" do
    user = admin_users(:david)
    actual = "".dup
    PP.pp(user, StringIO.new(actual))

    assert_includes actual, 'name: "[FILTERED]"'
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

  test "filter_attributes on pretty_print should handle [FILTERED] value properly" do
    User.filter_attributes = ["auth"]
    user = User.new(token: "[FILTERED]", auth_token: "[FILTERED]")
    actual = "".dup
    PP.pp(user, StringIO.new(actual))

    assert_includes actual, 'auth_token: "[FILTERED]"'
    assert_includes actual, 'token: "[FILTERED]"'
  ensure
    User.remove_instance_variable(:@filter_attributes)
  end
end
