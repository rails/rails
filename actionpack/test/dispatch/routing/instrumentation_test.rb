# frozen_string_literal: true

require "abstract_unit"

class RoutingInstrumentationTest < ActionDispatch::IntegrationTest
  test "redirect is instrumented" do
    draw do
      get "redirect", to: redirect("/login")
    end

    event = capture_notifications("redirect.action_dispatch") do
      assert_notifications_count("redirect.action_dispatch", 1) do
        get "/redirect"
      end
    end.first

    assert_equal 301, event.payload[:status]
    assert_equal "http://www.example.com/login", event.payload[:location]
    assert_kind_of ActionDispatch::Request, event.payload[:request]
  end

  private
    def draw(&block)
      self.class.stub_controllers do |routes|
        routes.default_url_options = { host: "www.example.com" }
        routes.draw(&block)
        @app = RoutedRackApp.new routes
      end
    end
end
