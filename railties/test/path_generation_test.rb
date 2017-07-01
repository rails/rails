require "abstract_unit"
require "active_support/core_ext/object/with_options"
require "active_support/core_ext/object/json"

class PathGenerationTest < ActiveSupport::TestCase
  attr_reader :app

  class TestSet < ActionDispatch::Routing::RouteSet
    def initialize(block)
      @block = block
      super()
    end

    class Request < DelegateClass(ActionDispatch::Request)
      def initialize(target, url_helpers, block)
        super(target)
        @url_helpers = url_helpers
        @block = block
      end

      def controller_class
        url_helpers = @url_helpers
        block = @block
        Class.new(ActionController::Base) {
          include url_helpers
          define_method(:process) { |name| block.call(self) }
          def to_a; [200, {}, []]; end
        }
      end
    end

    def make_request(env)
      Request.new(super, url_helpers, @block)
    end
  end

  def send_request(uri_or_host, method, path, script_name = nil)
    host = uri_or_host.host unless path
    path ||= uri_or_host.path

    params = { "PATH_INFO" => path,
              "REQUEST_METHOD" => method,
              "HTTP_HOST"      => host }

    params["SCRIPT_NAME"] = script_name if script_name

    status, headers, body = app.call(params)
    new_body = []
    body.each { |part| new_body << part }
    body.close if body.respond_to? :close
    [status, headers, new_body]
  end

  def test_original_script_name
    original_logger = Rails.logger
    Rails.logger    = Logger.new nil

    app = Class.new(Rails::Application) {
      attr_accessor :controller
      def initialize
        super
        app = self
        @routes = TestSet.new ->(c) { app.controller = c }
        secrets.secret_key_base = "foo"
        secrets.secret_token = "foo"
      end
      def app; routes; end
    }

    @app = app
    app.routes.draw { resource :blogs }

    url = URI("http://example.org/blogs")

    send_request(url, "GET", nil, "/FOO")
    assert_equal "/FOO/blogs", app.instance.controller.blogs_path

    send_request(url, "GET", nil)
    assert_equal "/blogs", app.instance.controller.blogs_path
  ensure
    Rails.logger = original_logger
  end
end
