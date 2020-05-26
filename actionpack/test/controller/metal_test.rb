# frozen_string_literal: true

require "abstract_unit"

class MetalControllerInstanceTests < ActiveSupport::TestCase
  class SimpleController < ActionController::Metal
    def hello
      self.response_body = "hello"
    end
  end

  def test_response_does_not_have_default_headers
    original_default_headers = ActionDispatch::Response.default_headers

    ActionDispatch::Response.default_headers = {
      "X-Frame-Options" => "DENY",
      "X-Content-Type-Options" => "nosniff",
      "X-XSS-Protection" => "1;"
    }

    response_headers = SimpleController.action("hello").call(
      "REQUEST_METHOD" => "GET",
      "rack.input" => -> { }
    )[1]

    assert_not response_headers.key?("X-Frame-Options")
    assert_not response_headers.key?("X-Content-Type-Options")
    assert_not response_headers.key?("X-XSS-Protection")
  ensure
    ActionDispatch::Response.default_headers = original_default_headers
  end

  def test_inspect
    controller = SimpleController.new
    assert_match(/#<MetalControllerInstanceTests::SimpleController:0x[0-9a-f]+>/, controller.inspect)
  end
end
