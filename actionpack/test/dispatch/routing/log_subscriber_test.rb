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

  test "verbose redirect logs" do
    old_cleaner = ActionDispatch::LogSubscriber.backtrace_cleaner
    ActionDispatch::LogSubscriber.backtrace_cleaner = ActionDispatch::LogSubscriber.backtrace_cleaner.dup
    ActionDispatch::LogSubscriber.backtrace_cleaner.add_silencer { |location| !location.include?(__FILE__) }
    ActionDispatch.verbose_redirect_logs = true

    draw do
      get "redirect", to: redirect("/login")
    end

    get "/redirect"
    wait

    assert_equal 3, logs.size
    assert_match(/↳ #{__FILE__}/, logs[1])
  ensure
    ActionDispatch.verbose_redirect_logs = false
    ActionDispatch::LogSubscriber.backtrace_cleaner = old_cleaner
  end

  private
    def draw(&block)
      self.class.stub_controllers do |routes|
        routes.default_url_options = { host: "www.example.com" }
        routes.draw(&block)
        @app = RoutedRackApp.new routes
      end
    end

    def get(path, **options)
      super(path, **options.merge(headers: { "action_dispatch.routes" => @app.routes }))
    end

    def logs
      @logs ||= @logger.logged(:info)
    end
end
