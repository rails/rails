# frozen_string_literal: true

require "abstract_unit"
require "capybara/dsl"
require "action_dispatch/system_testing/server"

class ServerTest < ActiveSupport::TestCase
  test "port is always included" do
    ActionDispatch::SystemTesting::Server.new.run
    assert Capybara.always_include_port, "expected Capybara.always_include_port to be true"
  end

  test "server is changed from `default` to `puma`" do
    Capybara.server = :default
    ActionDispatch::SystemTesting::Server.new.run
    assert_not_equal Capybara.server, Capybara.servers[:default]
  end

  test "server is not changed to `puma` when is different than default" do
    Capybara.server = :webrick
    ActionDispatch::SystemTesting::Server.new.run
    assert_equal Capybara.server, Capybara.servers[:webrick]
  end

  teardown do
    Capybara.server = :default
  end
end
