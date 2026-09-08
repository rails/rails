# frozen_string_literal: true

require "abstract_unit"

class RoutingInstrumentationTest < ActionDispatch::IntegrationTest
  test "redirect is instrumented" do
    draw do
      get "redirect", to: redirect("/login")
    end

    notification = assert_notification("redirect.action_dispatch", status: 301, location: "http://www.example.com/login") do
      get "/redirect"
    end

    assert_kind_of ActionDispatch::Request, notification.payload[:request]
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
