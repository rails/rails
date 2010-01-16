require 'abstract_unit'

module ActionDispatch
  class ShowExceptions
    private
      def public_path
        "#{FIXTURE_LOAD_PATH}/public"
      end

      # Silence logger
      def logger
        nil
      end
  end
end

class ShowExceptionsTest < ActionController::IntegrationTest
  Boomer = lambda do |env|
    req = ActionDispatch::Request.new(env)
    case req.path
    when "/not_found"
      raise ActionController::UnknownAction
    when "/method_not_allowed"
      raise ActionController::MethodNotAllowed
    when "/not_implemented"
      raise ActionController::NotImplemented
    when "/unprocessable_entity"
      raise ActionController::InvalidAuthenticityToken
    else
      raise "puke!"
    end
  end

  ProductionApp = ActionDispatch::ShowExceptions.new(Boomer, false)
  DevelopmentApp = ActionDispatch::ShowExceptions.new(Boomer, true)

  test "rescue in public from a remote ip" do
    @app = ProductionApp
    self.remote_addr = '208.77.188.166'

    get "/"
    assert_response 500
    assert_equal "500 error fixture\n", body

    get "/not_found"
    assert_response 404
    assert_equal "404 error fixture\n", body

    get "/method_not_allowed"
    assert_response 405
    assert_equal "", body
  end

  test "rescue locally from a local request" do
    @app = ProductionApp
    self.remote_addr = '127.0.0.1'

    get "/"
    assert_response 500
    assert_match /puke/, body

    get "/not_found"
    assert_response 404
    assert_match /#{ActionController::UnknownAction.name}/, body

    get "/method_not_allowed"
    assert_response 405
    assert_match /ActionController::MethodNotAllowed/, body
  end

  test "localize public rescue message" do
    # Change locale
    old_locale, I18n.locale = I18n.locale, :da

    begin
      @app = ProductionApp
      self.remote_addr = '208.77.188.166'

      get "/"
      assert_response 500
      assert_equal "500 localized error fixture\n", body

      get "/not_found"
      assert_response 404
      assert_equal "404 error fixture\n", body
    ensure
      I18n.locale = old_locale
    end
  end

  test "always rescue locally in development mode" do
    @app = DevelopmentApp
    self.remote_addr = '208.77.188.166'

    get "/"
    assert_response 500
    assert_match /puke/, body

    get "/not_found"
    assert_response 404
    assert_match /#{ActionController::UnknownAction.name}/, body

    get "/method_not_allowed"
    assert_response 405
    assert_match /ActionController::MethodNotAllowed/, body
  end

  test "publishes notifications" do
    # Wait pending notifications to be published
    ActiveSupport::Notifications.notifier.wait

    @app, event = ProductionApp, nil
    self.remote_addr = '127.0.0.1'

    ActiveSupport::Notifications.subscribe('action_dispatch.show_exception') do |*args|
      event = args
    end

    get "/"
    assert_response 500
    assert_match /puke/, body

    ActiveSupport::Notifications.notifier.wait

    assert_equal 'action_dispatch.show_exception', event.first
    assert_kind_of Hash, event.last[:env]
    assert_equal 'GET', event.last[:env]["REQUEST_METHOD"]
    assert_kind_of RuntimeError, event.last[:exception]
  end
end
