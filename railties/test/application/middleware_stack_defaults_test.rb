require 'isolation/abstract_unit'

class MiddlewareStackDefaultsTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    boot_rails
    require "rails"
    require "action_controller/railtie"

    Object.const_set(:MyApplication, Class.new(Rails::Application))
    MyApplication.class_eval do
      config.secret_token = "3b7cd727ee24e8444053437c36cc66c4"
      config.session_store :cookie_store, :key => "_myapp_session"
    end
  end

  def remote_ip(env = {})
    remote_ip = nil
    env = Rack::MockRequest.env_for("/").merge(env).merge('action_dispatch.show_exceptions' => false)

    endpoint = Proc.new do |e|
      remote_ip = ActionDispatch::Request.new(e).remote_ip
      [200, {}, ["Hello"]]
    end

    out = MyApplication.middleware.build(endpoint).call(env)
    remote_ip
  end

  test "remote_ip works" do
    assert_equal "1.1.1.1", remote_ip("REMOTE_ADDR" => "1.1.1.1")
  end

  test "checks IP spoofing by default" do
    assert_raises(ActionDispatch::RemoteIp::IpSpoofAttackError) do
      remote_ip("HTTP_X_FORWARDED_FOR" => "1.1.1.1", "HTTP_CLIENT_IP" => "1.1.1.2")
    end
  end

  test "can disable IP spoofing check" do
    MyApplication.config.action_dispatch.ip_spoofing_check = false

    assert_nothing_raised(ActionDispatch::RemoteIp::IpSpoofAttackError) do
      assert_equal "1.1.1.2", remote_ip("HTTP_X_FORWARDED_FOR" => "1.1.1.1", "HTTP_CLIENT_IP" => "1.1.1.2")
    end
  end

  test "the user can set trusted proxies" do
    MyApplication.config.action_dispatch.trusted_proxies = /^4\.2\.42\.42$/

    assert_equal "1.1.1.1", remote_ip("REMOTE_ADDR" => "4.2.42.42,1.1.1.1")
  end
end
