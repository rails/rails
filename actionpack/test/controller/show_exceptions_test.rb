require "abstract_unit"

module ShowExceptions
  class ShowExceptionsController < ActionController::Base
    use ActionDispatch::ShowExceptions, ActionDispatch::PublicExceptions.new("#{FIXTURE_LOAD_PATH}/public")
    use ActionDispatch::DebugExceptions

    before_action only: :another_boom do
      request.env["action_dispatch.show_detailed_exceptions"] = true
    end

    def boom
      raise "boom!"
    end

    def another_boom
      raise "boom!"
    end

    def show_detailed_exceptions?
      request.local?
    end
  end

  class ShowExceptionsTest < ActionDispatch::IntegrationTest
    test "show error page from a remote ip" do
      @app = ShowExceptionsController.action(:boom)
      self.remote_addr = "208.77.188.166"
      get "/"
      assert_equal "500 error fixture\n", body
    end

    test "show diagnostics from a local ip if show_detailed_exceptions? is set to request.local?" do
      @app = ShowExceptionsController.action(:boom)
      ["127.0.0.1", "127.0.0.127", "127.12.1.1", "::1", "0:0:0:0:0:0:0:1", "0:0:0:0:0:0:0:1%0"].each do |ip_address|
        self.remote_addr = ip_address
        get "/"
        assert_match(/boom/, body)
      end
    end

    test "show diagnostics from a remote ip when env is already set" do
      @app = ShowExceptionsController.action(:another_boom)
      self.remote_addr = "208.77.188.166"
      get "/"
      assert_match(/boom/, body)
    end
  end

  class ShowExceptionsOverriddenController < ShowExceptionsController
    private

    def show_detailed_exceptions?
      params["detailed"] == "1"
    end
  end

  class ShowExceptionsOverriddenTest < ActionDispatch::IntegrationTest
    test "show error page" do
      @app = ShowExceptionsOverriddenController.action(:boom)
      get "/", params: { "detailed" => "0" }
      assert_equal "500 error fixture\n", body
    end

    test "show diagnostics message" do
      @app = ShowExceptionsOverriddenController.action(:boom)
      get "/", params: { "detailed" => "1" }
      assert_match(/boom/, body)
    end
  end

  class ShowExceptionsFormatsTest < ActionDispatch::IntegrationTest
    def test_render_json_exception
      @app = ShowExceptionsOverriddenController.action(:boom)
      get "/", headers: { "HTTP_ACCEPT" => "application/json" }
      assert_response :internal_server_error
      assert_equal "application/json", response.content_type.to_s
      assert_equal({ status: 500, error: "Internal Server Error" }.to_json, response.body)
    end

    def test_render_xml_exception
      @app = ShowExceptionsOverriddenController.action(:boom)
      get "/", headers: { "HTTP_ACCEPT" => "application/xml" }
      assert_response :internal_server_error
      assert_equal "application/xml", response.content_type.to_s
      assert_equal({ status: 500, error: "Internal Server Error" }.to_xml, response.body)
    end

    def test_render_fallback_exception
      @app = ShowExceptionsOverriddenController.action(:boom)
      get "/", headers: { "HTTP_ACCEPT" => "text/csv" }
      assert_response :internal_server_error
      assert_equal "text/html", response.content_type.to_s
    end
  end

  class ShowFailsafeExceptionsTest < ActionDispatch::IntegrationTest
    def test_render_failsafe_exception
      @app = ShowExceptionsOverriddenController.action(:boom)
      @exceptions_app = @app.instance_variable_get(:@exceptions_app)
      @app.instance_variable_set(:@exceptions_app, nil)
      $stderr = StringIO.new

      get "/", headers: { "HTTP_ACCEPT" => "text/json" }
      assert_response :internal_server_error
      assert_equal "text/plain", response.content_type.to_s
    ensure
      @app.instance_variable_set(:@exceptions_app, @exceptions_app)
      $stderr = STDERR
    end
  end
end
