# frozen_string_literal: true

require "abstract_unit"
require "active_support/log_subscriber/test_helper"
require "action_dispatch/log_subscriber"

class RoutingLogSubscriberTest < ActionDispatch::IntegrationTest
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super
    ActionDispatch::LogSubscriber.attach_to :action_dispatch
  end

  test "redirect is logged" do
    draw do
      get "redirect", to: redirect("/login")
    end

    get "/redirect"
    wait

    assert_equal 2, logs.size
    assert_equal "Redirected to http://www.example.com/login", logs.first
    assert_match(/Completed 301/, logs.last)
  end

  private
    def draw(&block)
      self.class.stub_controllers do |routes|
        routes.default_url_options = { host: "www.example.com" }
        routes.draw(&block)
        @app = RoutedRackApp.new routes
      end
    end

    def logs
      @logs ||= @logger.logged(:info)
    end
end
