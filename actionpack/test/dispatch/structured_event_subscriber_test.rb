# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/event_reporter_assertions"
require "action_dispatch/structured_event_subscriber"

module ActionDispatch
  class StructuredEventSubscriberTest < ActionDispatch::IntegrationTest
    include ActiveSupport::Testing::EventReporterAssertions

    test "redirect is reported as structured event" do
      draw do
        get "redirect", to: redirect("/login")
      end

      event = assert_event_reported("action_dispatch.redirect", payload: {
        location: "http://www.example.com/login",
        status: 301,
        status_name: "Moved Permanently"
      }) do
        get "/redirect"
      end

      assert event[:payload][:duration_ms].is_a?(Numeric)
    end

    test "redirect with custom status is reported correctly" do
      draw do
        get "redirect", to: redirect("/moved", status: 302)
      end

      assert_event_reported("action_dispatch.redirect", payload: {
        location: "http://www.example.com/moved",
        status: 302,
        status_name: "Found"
      }) do
        get "/redirect"
      end
    end

    test "start of request.action_dispatch is reported as structured event" do
      request = ActionDispatch::Request.new(Rack::MockRequest.env_for(
        "/login?password=secret", method: "POST",
        "REMOTE_ADDR" => "1.2.3.4",
        "action_dispatch.parameter_filter" => [:password]
      ))

      handle = ActiveSupport::Notifications.instrumenter.build_handle("request.action_dispatch", request: request)

      assert_event_reported("action_dispatch.request_started", payload: {
        method: "POST",
        path: "/login?password=[FILTERED]",
        remote_ip: "1.2.3.4"
      }) do
        handle.start
      end

      assert_no_event_reported("action_dispatch.request_started") do
        handle.finish
      end
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
end
