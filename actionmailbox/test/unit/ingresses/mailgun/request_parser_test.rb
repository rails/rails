# frozen_string_literal: true

require_relative "../../../test_helper"

require "action_mailbox/ingresses/mailgun/request_parser"
require "rack/mock"

class ActionMailbox::Ingresses::Mailgun::RequestParserTest < ActiveSupport::TestCase
  PATH = ActionMailbox::Ingresses::Mailgun::RequestParser::PATH
  CONTENT_TYPE = ActionMailbox::Ingresses::Mailgun::RequestParser::CONTENT_TYPE

  test "parses Mailgun form data within the configured limit" do
    env = mailgun_env("foo=bar")

    parser(bytesize_limit: 7).call(env)

    assert_equal "foo=bar", env["rack.request.form_vars"]
    assert_equal [["foo", "bar"]], env["rack.request.form_pairs"]
    assert_equal "foo=bar", env["rack.input"].read
  end

  test "reads only enough data to reject a payload above the configured limit" do
    env = mailgun_env("foo=12345")
    rack_input = env["rack.input"]

    assert_raises Rack::QueryParser::QueryLimitError do
      parser(bytesize_limit: 5).call(env)
    end

    assert_equal 7, rack_input.pos
  end

  test "does not parse form data for unrelated endpoints" do
    env = mailgun_env("foo=bar", path: "/unrelated")
    rack_input = env["rack.input"]

    parser(bytesize_limit: 7).call(env)

    assert_same rack_input, env["rack.input"]
    assert_not env.key?("rack.request.form_vars")
    assert_not env.key?("rack.request.form_pairs")
    assert_equal 0, rack_input.pos
  end

  test "does not change Rack's payload size limit for unrelated endpoints" do
    env = mailgun_env("foo=#{"a" * 5.megabytes}", path: "/unrelated")
    app = ->(env) { Rack::Request.new(env).POST }

    assert_raises Rack::QueryParser::QueryLimitError do
      parser(app: app, bytesize_limit: 6.megabytes).call(env)
    end
  end

  private
    def parser(app: ->(_env) { [200, {}, []] }, bytesize_limit:)
      ActionMailbox::Ingresses::Mailgun::RequestParser.new(
        app,
        bytesize_limit: bytesize_limit
      )
    end

    def mailgun_env(body, path: PATH)
      Rack::MockRequest.env_for(path,
        method: "POST",
        input: body,
        "CONTENT_TYPE" => CONTENT_TYPE)
    end
end
