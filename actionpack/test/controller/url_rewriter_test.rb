require "abstract_unit"
require "controller/fake_controllers"

class UrlRewriterTests < ActionController::TestCase
  class Rewriter
    def initialize(request)
      @options = {
        host: request.host_with_port,
        protocol: request.protocol
      }
    end

    def rewrite(routes, options)
      routes.url_for(@options.merge(options))
    end
  end

  def setup
    @params = {}
    @rewriter = Rewriter.new(@request) #.new(@request, @params)
    @routes = ActionDispatch::Routing::RouteSet.new.tap do |r|
      r.draw do
        ActiveSupport::Deprecation.silence do
          get ":controller(/:action(/:id))"
        end
      end
    end
  end

  def test_port
    assert_equal("http://test.host:1271/c/a/i",
      @rewriter.rewrite(@routes, controller: "c", action: "a", id: "i", port: 1271)
    )
  end

  def test_protocol_with_and_without_separator
    assert_equal("https://test.host/c/a/i",
      @rewriter.rewrite(@routes, protocol: "https", controller: "c", action: "a", id: "i")
    )

    assert_equal("https://test.host/c/a/i",
      @rewriter.rewrite(@routes, protocol: "https://", controller: "c", action: "a", id: "i")
    )
  end

  def test_user_name_and_password
    assert_equal(
      "http://david:secret@test.host/c/a/i",
      @rewriter.rewrite(@routes, user: "david", password: "secret", controller: "c", action: "a", id: "i")
    )
  end

  def test_user_name_and_password_with_escape_codes
    assert_equal(
      "http://openid.aol.com%2Fnextangler:one+two%3F@test.host/c/a/i",
      @rewriter.rewrite(@routes, user: "openid.aol.com/nextangler", password: "one two?", controller: "c", action: "a", id: "i")
    )
  end

  def test_anchor
    assert_equal(
      "http://test.host/c/a/i#anchor",
      @rewriter.rewrite(@routes, controller: "c", action: "a", id: "i", anchor: "anchor")
    )
  end

  def test_anchor_should_call_to_param
    assert_equal(
      "http://test.host/c/a/i#anchor",
      @rewriter.rewrite(@routes, controller: "c", action: "a", id: "i", anchor: Struct.new(:to_param).new("anchor"))
    )
  end

  def test_anchor_should_be_uri_escaped
    assert_equal(
      "http://test.host/c/a/i#anc/hor",
      @rewriter.rewrite(@routes, controller: "c", action: "a", id: "i", anchor: Struct.new(:to_param).new("anc/hor"))
    )
  end

  def test_trailing_slash
    options = {controller: "foo", action: "bar", id: "3", only_path: true}
    assert_equal "/foo/bar/3", @rewriter.rewrite(@routes, options)
    assert_equal "/foo/bar/3?query=string", @rewriter.rewrite(@routes, options.merge({query: "string"}))
    options.update({trailing_slash: true})
    assert_equal "/foo/bar/3/", @rewriter.rewrite(@routes, options)
    options.update({query: "string"})
    assert_equal "/foo/bar/3/?query=string", @rewriter.rewrite(@routes, options)
  end
end

