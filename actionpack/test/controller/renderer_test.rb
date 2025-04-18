# frozen_string_literal: true

require "abstract_unit"
require "test_renderable"

class RendererTest < ActiveSupport::TestCase
  test "action controller base has a renderer" do
    assert ActionController::Base.renderer
  end

  test "creating with a controller" do
    controller = CommentsController
    renderer   = ActionController::Renderer.for controller

    assert_equal controller, renderer.controller
  end

  test "creating from a controller" do
    controller = AccountsController
    renderer   = controller.renderer

    assert_equal controller, renderer.controller
  end

  test "creating with new defaults" do
    renderer = ApplicationController.renderer

    new_defaults = { https: true }
    new_renderer = renderer.with_defaults(new_defaults).new
    content = new_renderer.render(inline: "<%= request.ssl? %>")

    assert_equal "true", content
  end

  test "rendering with a class renderer" do
    renderer = ApplicationController.renderer
    content  = renderer.render template: "ruby_template"

    assert_equal "Hello from Ruby code", content
  end

  test "rendering with an instance renderer" do
    renderer = ApplicationController.renderer.new
    content  = renderer.render template: "test/hello_world"

    assert_equal "Hello world!", content
  end

  test "rendering with a controller class" do
    assert_equal "Hello world!", ApplicationController.render("test/hello_world")
  end

  test "rendering with locals" do
    renderer = ApplicationController.renderer
    content  = renderer.render template: "test/render_file_with_locals",
                               locals: { secret: "bar" }

    assert_equal "The secret is bar\n", content
  end

  test "rendering with assigns" do
    renderer = ApplicationController.renderer
    content  = renderer.render template: "test/render_file_with_ivar",
                               assigns: { secret: "foo" }

    assert_equal "The secret is foo\n", content
  end

  test "render a renderable object" do
    renderer = ApplicationController.renderer

    assert_equal(
      %(Hello, World!),
      renderer.render(TestRenderable.new)
    )
    assert_equal(
      %(Hello, World!),
      renderer.render(renderable: TestRenderable.new)
    )
  end

  test "rendering with custom env" do
    renderer = ApplicationController.renderer.new method: "post"
    content  = renderer.render inline: "<%= request.post? %>"

    assert_equal "true", content
  end

  test "rendering with custom env using a key that is not in RACK_KEY_TRANSLATION" do
    value    = "warden is here"
    renderer = ApplicationController.renderer.new warden: value
    content  = renderer.render inline: "<%= request.env['warden'] %>"

    assert_equal value, content
  end

  test "rendering with defaults" do
    renderer = ApplicationController.renderer.new https: true
    content = renderer.render inline: "<%= request.ssl? %>"

    assert_equal "true", content
  end

  test "same defaults from the same controller" do
    renderer_defaults = ->(controller) { controller.renderer.defaults }

    assert_equal renderer_defaults[AccountsController], renderer_defaults[AccountsController]
    assert_equal renderer_defaults[AccountsController], renderer_defaults[CommentsController]
  end

  test "rendering with different formats" do
    html = "Hello world!"
    xml  = "<p>Hello world!</p>\n"

    assert_equal html, render("respond_to/using_defaults")
    assert_equal xml,  render("respond_to/using_defaults", formats: :xml)
  end

  test "rendering with helpers" do
    assert_equal "<p>1\n<br />2</p>", render(inline: '<%= simple_format "1\n2" %>')
  end

  test "rendering with user specified defaults" do
    renderer.defaults.merge!(hello: "hello", https: true)
    content = renderer.new.render inline: "<%= request.ssl? %>"

    assert_equal "true", content
  end

  test "return valid asset URL with defaults" do
    renderer = ApplicationController.renderer
    content  = renderer.render inline: "<%= asset_url 'asset.jpg' %>"

    assert_equal "http://example.org/asset.jpg", content
  end

  test "return valid asset URL when https is true" do
    renderer = ApplicationController.renderer.new https: true
    content  = renderer.render inline: "<%= asset_url 'asset.jpg' %>"

    assert_equal "https://example.org/asset.jpg", content
  end

  test "uses default_url_options from the controller's routes when env[:http_host] not specified" do
    with_default_url_options(
      protocol: "https",
      host: "foo.example.com",
      port: 9001,
      script_name: "/bar",
    ) do
      assert_equal "https://foo.example.com:9001/bar/posts", render_url_for(controller: :posts)
    end
  end

  test "uses config.force_ssl when env[:http_host] not specified" do
    with_default_url_options(host: "foo.example.com") do
      with_force_ssl do
        assert_equal "https://foo.example.com/posts", render_url_for(controller: :posts)
      end
    end
  end

  test "can specify env[:https] when using default_url_options" do
    with_default_url_options(host: "foo.example.com") do
      @renderer = renderer.new(https: true)
      assert_equal "https://foo.example.com/posts", render_url_for(controller: :posts)
    end
  end

  test "env[:https] overrides default_url_options[:protocol]" do
    with_default_url_options(host: "foo.example.com", protocol: "https") do
      @renderer = renderer.new(https: false)
      assert_equal "http://foo.example.com/posts", render_url_for(controller: :posts)
    end
  end

  test "can specify env[:script_name] when using default_url_options" do
    with_default_url_options(host: "foo.example.com") do
      @renderer = renderer.new(script_name: "/bar")
      assert_equal "http://foo.example.com/bar/posts", render_url_for(controller: :posts)
    end
  end

  test "env[:script_name] overrides default_url_options[:script_name]" do
    with_default_url_options(host: "foo.example.com", script_name: "/bar") do
      @renderer = renderer.new(script_name: "")
      assert_equal "http://foo.example.com/posts", render_url_for(controller: :posts)
    end
  end

  private
    def renderer
      @renderer ||= ApplicationController.renderer.new
    end

    def render(...)
      renderer.render(...)
    end

    def render_url_for(*args)
      render inline: "<%= full_url_for(*#{args.inspect}) %>"
    end

    def with_default_url_options(default_url_options)
      original_default_url_options = renderer.controller._routes.default_url_options
      renderer.controller._routes.default_url_options = default_url_options
      yield
    ensure
      renderer.controller._routes.default_url_options = original_default_url_options
      renderer.controller._routes.default_env # refresh
    end

    def with_force_ssl(force_ssl = true)
      # In a real app, an initializer will set `URL.secure_protocol = app.config.force_ssl`.
      original_secure_protocol = ActionDispatch::Http::URL.secure_protocol
      ActionDispatch::Http::URL.secure_protocol = force_ssl
      yield
    ensure
      ActionDispatch::Http::URL.secure_protocol = original_secure_protocol
    end
end
