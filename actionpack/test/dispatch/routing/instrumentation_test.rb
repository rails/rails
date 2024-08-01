# frozen_string_literal: true

require "abstract_unit"

class RoutingInstrumentationTest < ActionDispatch::IntegrationTest
  test "redirect is instrumented" do
    draw do
      get "redirect", to: redirect("/login")
    end

    event = subscribed("redirect.action_dispatch") { get "/redirect" }

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

    def subscribed(event_pattern, &block)
      event = nil
      subscriber = -> (_event) { event = _event }
      ActiveSupport::Notifications.subscribed(subscriber, event_pattern, &block)
      event
    end
end
