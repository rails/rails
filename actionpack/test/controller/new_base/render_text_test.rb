require "abstract_unit"

module RenderText
  class MinimalController < ActionController::Metal
    include AbstractController::Rendering
    include ActionController::Rendering

    def index
      render text: "Hello World!"
    end
  end

  class SimpleController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new]

    def index
      render text: "hello david"
    end
  end

  class WithLayoutController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      "layouts/application.html.erb" => "<%= yield %>, I'm here!",
      "layouts/greetings.html.erb"   => "<%= yield %>, I wish thee well.",
      "layouts/ivar.html.erb"        => "<%= yield %>, <%= @ivar %>"
    )]

    def index
      render text: "hello david"
    end

    def custom_code
      render text: "hello world", status: 404
    end

    def with_custom_code_as_string
      render text: "hello world", status: "404 Not Found"
    end

    def with_nil
      render text: nil
    end

    def with_nil_and_status
      render text: nil, status: 403
    end

    def with_false
      render text: false
    end

    def with_layout_true
      render text: "hello world", layout: true
    end

    def with_layout_false
      render text: "hello world", layout: false
    end

    def with_layout_nil
      render text: "hello world", layout: nil
    end

    def with_custom_layout
      render text: "hello world", layout: "greetings"
    end

    def with_ivar_in_layout
      @ivar = "hello world"
      render text: "hello world", layout: "ivar"
    end
  end

  class RenderTextTest < Rack::TestCase
    test "rendering text from a minimal controller" do
      ActiveSupport::Deprecation.silence do
        get "/render_text/minimal/index"
      end

      assert_body "Hello World!"
      assert_status 200
    end

    test "rendering text from an action with default options renders the text with the layout" do
      with_routing do |set|
        set.draw { ActiveSupport::Deprecation.silence { get ":controller", action: "index" } }

        ActiveSupport::Deprecation.silence do
          get "/render_text/simple"
        end

        assert_body "hello david"
        assert_status 200
      end
    end

    test "rendering text from an action with default options renders the text without the layout" do
      with_routing do |set|
        set.draw { ActiveSupport::Deprecation.silence { get ":controller", action: "index" } }

        ActiveSupport::Deprecation.silence do
          get "/render_text/with_layout"
        end

        assert_body "hello david"
        assert_status 200
      end
    end

    test "rendering text, while also providing a custom status code" do
      ActiveSupport::Deprecation.silence do
        get "/render_text/with_layout/custom_code"
      end

      assert_body "hello world"
      assert_status 404
    end

    test "rendering text with nil returns an empty body" do
      ActiveSupport::Deprecation.silence do
        get "/render_text/with_layout/with_nil"
      end

      assert_body ""
      assert_status 200
    end

    test "Rendering text with nil and custom status code returns an empty body and the status" do
      ActiveSupport::Deprecation.silence do
        get "/render_text/with_layout/with_nil_and_status"
      end

      assert_body ""
      assert_status 403
    end

    test "rendering text with false returns the string 'false'" do
      ActiveSupport::Deprecation.silence do
        get "/render_text/with_layout/with_false"
      end

      assert_body "false"
      assert_status 200
    end

    test "rendering text with layout: true" do
      ActiveSupport::Deprecation.silence do
        get "/render_text/with_layout/with_layout_true"
      end

      assert_body "hello world, I'm here!"
      assert_status 200
    end

    test "rendering text with layout: 'greetings'" do
      ActiveSupport::Deprecation.silence do
        get "/render_text/with_layout/with_custom_layout"
      end

      assert_body "hello world, I wish thee well."
      assert_status 200
    end

    test "rendering text with layout: false" do
      ActiveSupport::Deprecation.silence do
        get "/render_text/with_layout/with_layout_false"
      end

      assert_body "hello world"
      assert_status 200
    end

    test "rendering text with layout: nil" do
      ActiveSupport::Deprecation.silence do
        get "/render_text/with_layout/with_layout_nil"
      end

      assert_body "hello world"
      assert_status 200
    end

    test "rendering text displays deprecation warning" do
      assert_deprecated do
        get "/render_text/with_layout/with_layout_nil"
      end
    end
  end
end
