# frozen_string_literal: true

require "abstract_unit"

class PublicExceptionsTest < ActiveSupport::TestCase
  setup do
    @tmpdir = Dir.mktmpdir
    @public_exception = ActionDispatch::PublicExceptions.new(@tmpdir)
  end

  teardown do
    FileUtils.rm_rf(@tmpdir)
  end

  test "render the 404 page when a 404.html file exists and the request format is text/html" do
    write_template("404.html", "This page doesn't exist")

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/404",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal("This page doesn't exist", body.body)
  end

  test "render the 404 page when a 404.html.erb file exists and the request format is text/html" do
    write_template("404.html.erb", "<%= link_to('Back', 'https://example.org') %>")

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/404",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal('<a href="https://example.org">Back</a>', body.body)
  end

  test "render the 404 page when a 404.json.erb file exists and the request format is application/json" do
    write_template("404.json.erb", '{"request_id":<%= request.request_id %>}')

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "application/json",
      "PATH_INFO" => "/404",
      "action_dispatch.request_id" => "1234",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal('{"request_id":1234}', body.body)
  end

  test "render a generic response when no template exists for a given content-type" do
    write_template("404.html", "This page doesn't exist")

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "application/json",
      "PATH_INFO" => "/404",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal('{"status":404,"error":"Not Found"}', body.body)
  end

  test "render a 404 html page when a generic response for a content-type can't be returned" do
    write_template("404.html", "This page doesn't exist")

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "application/rss+xml",
      "PATH_INFO" => "/404",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal("This page doesn't exist", body.body)
  end

  test "render a 404 html page when no formats can be determined" do
    write_template("404.html", "This page doesn't exist")

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "application/foo+bar",
      "PATH_INFO" => "/404",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal("This page doesn't exist", body.body)
  end

  test "return a 404 when the code is not a http status code" do
    status, headers, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/314141241",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal({ ActionDispatch::Constants::X_CASCADE => "pass", Rack::CONTENT_TYPE => "text/html" }, headers)
    assert_empty(body.body)
  end

  test "render a page if the corresponding error template exists" do
    write_template("401.html", "You are not authorized")

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/401",
      "rack.input" => "",
    )

    assert_equal(401, status)
    assert_equal("You are not authorized", body.body)
  end

  test "return a 404 if no corresponding template exists and no generic response can be returned for a content-type" do
    status, headers, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/401",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal({ ActionDispatch::Constants::X_CASCADE => "pass", Rack::CONTENT_TYPE => "text/html" }, headers)
    assert_empty(body.body)
  end

  test "render the translated error page in priority" do
    write_template("404.html", "This page doesn't exist")
    write_template("404.fr.html", "Cette page est introuvable")

    old_locale = I18n.locale
    I18n.locale = :fr

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/404",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal("Cette page est introuvable", body.body)
  ensure
    I18n.locale = old_locale
  end

  test "render the page with the 'errors' layout when it exists" do
    Dir.mkdir("#{@tmpdir}/layouts")
    write_template("layouts/errors.html.erb", <<~ERB)
      <!DOCTYPE html>
      <html lang="en">
        <body>
          <%= yield %>
        </body>
      </html>
    ERB
    write_template("404.html.erb", "This page doesn't exist")

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/404",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal(<<~EXPECTED, body.body)
      <!DOCTYPE html>
      <html lang="en">
        <body>
          This page doesn't exist
        </body>
      </html>
    EXPECTED
  end

  test "has access to thes routes url helpers when available" do
    route_set = ActionDispatch::Routing::RouteSet.new.tap do |routes|
      routes.draw { root to: redirect("") }
    end

    @public_exception = ActionDispatch::PublicExceptions.new(@tmpdir, route_set)

    write_template("404.html.erb", <<~ERB)
      Return to the <%= link_to('home page', root_path) %>.
      View our <%= link_to('docs', root_url) %>.
    ERB

    status, _, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/404",
      "HTTP_HOST" => "example.org",
      "HTTPS" => "on",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal(<<~EXPECTED, body.body)
      Return to the <a href="/">home page</a>.
      View our <a href="https://example.org/">docs</a>.
    EXPECTED
  end

  test "inserting a middleware on the controller" do
    previous = ActionDispatch::ExceptionsController.middleware_stack.dup
    my_middleware = Class.new do
      def initialize(app)
        @app = app
      end

      def call(env)
        result = @app.call(env)
        result[1]["canary-app.throttled"] = "1"

        result
      end
    end

    ActionDispatch::ExceptionsController.use(my_middleware)

    write_template("404.html", "This page doesn't exist")

    status, headers, body = @public_exception.call(
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "text/html",
      "PATH_INFO" => "/404",
      "rack.input" => "",
    )

    assert_equal(404, status)
    assert_equal("This page doesn't exist", body.body)
    assert_equal("1", headers["canary-app.throttled"])
  ensure
    ActionDispatch::ExceptionsController.middleware_stack = previous
  end

  private
    def write_template(name, content)
      File.write("#{@tmpdir}/#{name}", content)
    end
end
