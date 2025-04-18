# frozen_string_literal: true

require "abstract_unit"

class AssumeSSLTest < ActiveSupport::TestCase
  test "sets expected headers" do
    app = lambda { |_env| [ 200, {}, [] ] }
    env = Rack::MockRequest.env_for("", {})

    Rack::Lint.new(
      ActionDispatch::AssumeSSL.new(
        Rack::Lint.new(app)
      )
    ).call(env)

    assert_equal "on", env["HTTPS"]
    assert_equal "443", env["HTTP_X_FORWARDED_PORT"]
    assert_equal "https", env["HTTP_X_FORWARDED_PROTO"]
    assert_equal "https", env["rack.url_scheme"]
  end
end
