require 'isolation/abstract_unit'

module ApplicationTests
  class RemoteIpTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def remote_ip(env = {})
      remote_ip = nil
      env = Rack::MockRequest.env_for("/").merge(env).merge!(
        'action_dispatch.show_exceptions' => false,
        'action_dispatch.secret_token' => 'b3c631c314c0bbca50c1b2843150fe33'
      )

      endpoint = Proc.new do |e|
        remote_ip = ActionDispatch::Request.new(e).remote_ip
        [200, {}, ["Hello"]]
      end

      Rails.application.middleware.build(endpoint).call(env)
      remote_ip
    end

    test "remote_ip works" do
      make_basic_app
      assert_equal "1.1.1.1", remote_ip("REMOTE_ADDR" => "1.1.1.1")
    end

    test "checks IP spoofing by default" do
      make_basic_app
      assert_raises(ActionDispatch::RemoteIp::IpSpoofAttackError) do
        remote_ip("HTTP_X_FORWARDED_FOR" => "1.1.1.1", "HTTP_CLIENT_IP" => "1.1.1.2")
      end
    end

    test "can disable IP spoofing check" do
      make_basic_app do |app|
        app.config.action_dispatch.ip_spoofing_check = false
      end

      assert_nothing_raised(ActionDispatch::RemoteIp::IpSpoofAttackError) do
        assert_equal "1.1.1.2", remote_ip("HTTP_X_FORWARDED_FOR" => "1.1.1.1", "HTTP_CLIENT_IP" => "1.1.1.2")
      end
    end

    test "the user can set trusted proxies" do
      make_basic_app do |app|
        app.config.action_dispatch.trusted_proxies = /^4\.2\.42\.42$/
      end

      assert_equal "1.1.1.1", remote_ip("REMOTE_ADDR" => "4.2.42.42,1.1.1.1")
    end
  end
end
