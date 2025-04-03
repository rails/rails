# frozen_string_literal: true

require "abstract_unit"
require "timeout"
require "concurrent/atomic/count_down_latch"
require "zeitwerk"

Thread.abort_on_exception = true

module ActionController
  class SSETest < ActionController::TestCase
    class SSETestController < ActionController::Base
      include ActionController::Live

      def basic_sse
        response.headers["Content-Type"] = "text/event-stream"
        sse = SSE.new(response.stream)
        sse.write("{\"name\":\"John\"}")
        sse.write(name: "Ryan")
      ensure
        sse.close
      end

      def sse_with_event
        sse = SSE.new(response.stream, event: "send-name")
        sse.write("{\"name\":\"John\"}")
        sse.write(name: "Ryan")
      ensure
        sse.close
      end

      def sse_with_retry
        sse = SSE.new(response.stream, retry: 1000)
        sse.write("{\"name\":\"John\"}")
        sse.write({ name: "Ryan" }, { retry: 1500 })
      ensure
        sse.close
      end

      def sse_with_id
        sse = SSE.new(response.stream)
        sse.write("{\"name\":\"John\"}", id: 1)
        sse.write({ name: "Ryan" }, { id: 2 })
      ensure
        sse.close
      end

      def sse_with_multiple_line_message
        sse = SSE.new(response.stream)
        sse.write("first line.\nsecond line.")
      ensure
        sse.close
      end
    end

    tests SSETestController

    def wait_for_response_stream_close
      response.body
    end

    def test_basic_sse
      get :basic_sse

      wait_for_response_stream_close
      assert_match(/data: {"name":"John"}/, response.body)
      assert_match(/data: {"name":"Ryan"}/, response.body)
    end

    def test_sse_with_event_name
      get :sse_with_event

      wait_for_response_stream_close
      assert_match(/data: {"name":"John"}/, response.body)
      assert_match(/data: {"name":"Ryan"}/, response.body)
      assert_match(/event: send-name/, response.body)
    end

    def test_sse_with_retry
      get :sse_with_retry

      wait_for_response_stream_close
      first_response, second_response = response.body.split("\n\n")
      assert_match(/data: {"name":"John"}/, first_response)
      assert_match(/retry: 1000/, first_response)

      assert_match(/data: {"name":"Ryan"}/, second_response)
      assert_match(/retry: 1500/, second_response)
    end

    def test_sse_with_id
      get :sse_with_id

      wait_for_response_stream_close
      first_response, second_response = response.body.split("\n\n")
      assert_match(/data: {"name":"John"}/, first_response)
      assert_match(/id: 1/, first_response)

      assert_match(/data: {"name":"Ryan"}/, second_response)
      assert_match(/id: 2/, second_response)
    end

    def test_sse_with_multiple_line_message
      get :sse_with_multiple_line_message

      wait_for_response_stream_close
      first_response, second_response = response.body.split("\n")
      assert_match(/data: first line/, first_response)
      assert_match(/data: second line/, second_response)
    end
  end

  class LiveStreamTest < ActionController::TestCase
    class Exception < StandardError
    end

    class CurrentState < ActiveSupport::CurrentAttributes
      attribute :id
    end

    class TestController < ActionController::Base
      include ActionController::Live

      attr_accessor :latch, :tc, :error_latch

      def self.controller_path
        "test"
      end

      def set_cookie
        cookies[:hello] = "world"
        response.stream.write "hello world"
        response.close
      end

      def render_text
        render plain: "zomg"
      end

      def write_lines
        response.stream.writeln "hello\n"
        response.stream.writeln "world"
        response.stream.close
      end

      def default_header
        response.stream.write "<html><body>hi</body></html>"
        response.stream.close
      end

      def basic_stream
        response.headers["Content-Type"] = "text/event-stream"
        %w{ hello world }.each do |word|
          response.stream.write word
        end
        response.stream.close
      end

      def basic_send_stream
        send_stream(filename: "my.csv") do |stream|
          stream.write "name,age\ndavid,41"
        end
      end

      def send_stream_with_options
        send_stream(filename: "export", disposition: "inline", type: :json) do |stream|
          stream.write %[{ name: "David", age: 41 }]
        end
      end

      def send_stream_with_inferred_content_type
        send_stream(filename: "sample.csv") do |stream|
          stream.writeln "fruit,quantity"
          stream.writeln "apple,5"
        end
      end

      def send_stream_with_implicit_content_type
        send_stream(filename: "sample.csv", type: :csv) do |stream|
          stream.writeln "fruit,quantity"
          stream.writeln "apple,5"
        end
      end

      def send_stream_with_explicit_content_type
        send_stream(filename: "sample.csv", type: "text/csv") do |stream|
          stream.writeln "fruit,quantity"
          stream.writeln "apple,5"
        end
      end

      def blocking_stream
        response.headers["Content-Type"] = "text/event-stream"
        %w{ hello world }.each do |word|
          response.stream.write word
          latch.wait
        end
        response.stream.close
      end

      def write_sleep_autoload
        path = File.expand_path("../fixtures", __dir__)
        Zeitwerk.with_loader do |loader|
          loader.push_dir(path)
          loader.ignore(File.join(path, "公共"))
          loader.setup

          response.headers["Content-Type"] = "text/event-stream"
          response.stream.write "before load"
          sleep 0.01
          silence_warnings do
            ::LoadMe
          end
          response.stream.close
          latch.count_down
        ensure
          loader.unload
        end
      end

      def thread_locals
        tc.assert_equal "aaron", Thread.current[:setting]

        response.headers["Content-Type"] = "text/event-stream"
        %w{ hello world }.each do |word|
          response.stream.write word
        end
        response.stream.close
      end

      def no_thread_locals
        tc.assert_nil Thread.current[:setting]

        response.headers["Content-Type"] = "text/event-stream"
        %w{ hello world }.each do |word|
          response.stream.write word
        end
        response.stream.close
      end

      def isolated_state
        render plain: CurrentState.id.inspect
      end

      def raw_isolated_state
        render plain: ActiveSupport::IsolatedExecutionState[:raw_isolated_state].inspect
      end

      def with_stale
        render plain: "stale" if stale?(etag: "123", template: false)
      end

      def exception_in_view
        render "doesntexist"
      end

      def exception_in_view_after_commit
        response.stream.write ""
        render "doesntexist"
      end

      def exception_with_callback
        response.headers["Content-Type"] = "text/event-stream"

        response.stream.on_error do
          response.stream.write %(data: "500 Internal Server Error"\n\n)
          response.stream.close
        end

        response.stream.write "" # make sure the response is committed
        raise "An exception occurred..."
      end

      def exception_in_controller
        raise Exception, "Exception in controller"
      end

      def bad_request_error
        raise ActionController::BadRequest
      end

      def exception_in_exception_callback
        response.headers["Content-Type"] = "text/event-stream"
        response.stream.on_error do
          raise "We need to go deeper."
        end
        response.stream.write ""
        response.stream.write params[:widget][:didnt_check_for_nil]
      end

      def overfill_buffer_and_die
        logger = ActionController::Base.logger || Logger.new($stdout)
        response.stream.on_error do
          logger.warn "Error while streaming."
          error_latch.count_down
        end

        # Write until the buffer is full. It doesn't expose that
        # information directly, so we must hard-code its size:
        10.times do
          response.stream.write "."
        end
        # .. plus one more, because the #each frees up a slot:
        response.stream.write "."

        latch.count_down

        # This write will block, and eventually raise
        response.stream.write "x"

        20.times do
          response.stream.write "."
        end
      end

      def overfill_default_buffer
        ("a".."z").each do |char|
          response.stream.write(char)
        end
        response.stream.close
      end

      def ignore_client_disconnect
        response.stream.ignore_disconnect = true

        response.stream.write "" # commit

        # These writes will be ignored
        15.times do
          response.stream.write "x"
        end

        logger.info "Work complete"
        latch.count_down
      end
    end

    tests TestController

    def assert_stream_closed
      assert_predicate response.stream, :closed?, "stream should be closed"
      assert_predicate response, :committed?,     "response should be committed"
      assert_predicate response, :sent?,          "response should be sent"
    end

    def capture_log_output
      output = StringIO.new
      old_logger, ActionController::Base.logger = ActionController::Base.logger, ActiveSupport::Logger.new(output)

      begin
        yield output
      ensure
        ActionController::Base.logger = old_logger
      end
    end

    def setup
      super

      def @controller.new_controller_thread(&block)
        original_new_controller_thread(&block)
      end

      def @controller.clean_up_thread_locals(*args)
        original_clean_up_thread_locals(*args)
      end
    end

    def test_set_cookie
      get :set_cookie
      assert_equal({ "hello" => "world" }, @response.cookies)
      assert_equal "hello world", @response.body
    end

    def test_write_to_stream
      get :basic_stream
      assert_equal "helloworld", @response.body
      assert_equal "text/event-stream", @response.headers["Content-Type"]
    end

    def test_write_lines_to_stream
      get :write_lines
      assert_equal "hello\nworld\n", @response.body
    end

    def test_send_stream
      get :basic_send_stream
      assert_equal "name,age\ndavid,41", @response.body
      assert_equal "text/csv", @response.headers["Content-Type"]
      assert_match "attachment", @response.headers["Content-Disposition"]
      assert_match "my.csv", @response.headers["Content-Disposition"]
    end

    def test_send_stream_instrumentation
      expected_payload = {
        filename: "sample.csv",
        disposition: "attachment",
        type: "text/csv"
      }

      assert_notification("send_stream.action_controller", expected_payload) do
        get :send_stream_with_explicit_content_type
      end
    end

    def test_send_stream_with_options
      get :send_stream_with_options
      assert_equal %[{ name: "David", age: 41 }], @response.body
      assert_equal "application/json", @response.headers["Content-Type"]
      assert_match "inline", @response.headers["Content-Disposition"]
      assert_match "export", @response.headers["Content-Disposition"]
    end

    def test_send_stream_with_explicit_content_type
      get :send_stream_with_explicit_content_type

      assert_equal "fruit,quantity\napple,5\n", @response.body

      content_type = @response.headers.fetch("Content-Type")
      assert_equal String, content_type.class
      assert_equal "text/csv", content_type
    end

    def test_send_stream_with_implicit_content_type
      get :send_stream_with_implicit_content_type

      assert_equal "fruit,quantity\napple,5\n", @response.body

      content_type = @response.headers.fetch("Content-Type")
      assert_equal String, content_type.class
      assert_equal "text/csv", content_type
    end

    def test_send_stream_with_inferred_content_type
      get :send_stream_with_inferred_content_type

      assert_equal "fruit,quantity\napple,5\n", @response.body

      content_type = @response.headers.fetch("Content-Type")
      assert_equal String, content_type.class
      assert_equal "text/csv", content_type
    end

    def test_delayed_autoload_after_write_within_interlock_hook
      # Simulate InterlockHook
      ActiveSupport::Dependencies.interlock.start_running
      res = get :write_sleep_autoload
      res.each { }
      ActiveSupport::Dependencies.interlock.done_running
      pass
    end

    def test_async_stream
      @controller.latch = Concurrent::CountDownLatch.new
      parts             = ["hello", "world"]

      get :blocking_stream

      t = Thread.new(response) { |resp|
        resp.await_commit
        resp.stream.each do |part|
          assert_equal parts.shift, part
          ol = @controller.latch
          @controller.latch = Concurrent::CountDownLatch.new
          ol.count_down
        end
      }

      assert t.join(3), "timeout expired before the thread terminated"
    end

    def test_infinite_test_buffer
      get :overfill_default_buffer
      assert_equal ("a".."z").to_a.join, response.stream.body
    end

    def test_abort_with_full_buffer
      old_queue_size = ActionController::Live::Buffer.queue_size
      ActionController::Live::Buffer.queue_size = 10

      @controller.latch = Concurrent::CountDownLatch.new
      @controller.error_latch = Concurrent::CountDownLatch.new

      capture_log_output do |output|
        get :overfill_buffer_and_die, format: "plain"

        t = Thread.new(response) { |resp|
          resp.await_commit
          _, _, body = resp.to_a
          body.each do
            @controller.latch.wait
            body.close
            break
          end
        }

        t.join
        @controller.error_latch.wait
        assert_match "Error while streaming", output.rewind && output.read
      end
    ensure
      ActionController::Live::Buffer.queue_size = old_queue_size
    end

    def test_ignore_client_disconnect
      @controller.latch = Concurrent::CountDownLatch.new

      capture_log_output do |output|
        get :ignore_client_disconnect

        t = Thread.new(response) { |resp|
          resp.await_commit
          _, _, body = resp.to_a
          body.each do
            body.close
            break
          end
        }

        t.join
        Timeout.timeout(3) do
          @controller.latch.wait
        end
        assert_match "Work complete", output.rewind && output.read
      end
    end

    def test_thread_locals_get_copied
      @controller.tc = self
      Thread.current[:originating_thread] = Thread.current.object_id
      Thread.current[:setting]            = "aaron"

      get :thread_locals
    end

    def test_isolated_state_get_copied
      @controller.tc = self
      CurrentState.id = "isolated_state"

      get :isolated_state
      assert_equal "isolated_state".inspect, response.body
      assert_stream_closed
    end

    def test_thread_locals_get_reset
      @controller.tc = self

      Thread.current[:originating_thread] = Thread.current.object_id
      Thread.current[:setting]            = "aaron"

      get :thread_locals

      Thread.current[:setting] = nil

      get :no_thread_locals
    end

    def test_isolated_state_get_reset
      @controller.tc = self
      ActiveSupport::IsolatedExecutionState[:raw_isolated_state] = "buffy"

      get :raw_isolated_state
      assert_equal "buffy".inspect, response.body
      assert_stream_closed

      ActiveSupport::IsolatedExecutionState.clear

      get :isolated_state
      assert_equal nil.inspect, response.body
      assert_stream_closed
    end

    def test_live_stream_default_header
      get :default_header
      assert response.headers["Content-Type"]
    end

    def test_render_text
      get :render_text
      assert_equal "zomg", response.body
      assert_stream_closed
    end

    def test_exception_handling_html
      assert_raises(ActionView::MissingTemplate) do
        get :exception_in_view
      end

      capture_log_output do |output|
        get :exception_in_view_after_commit
        assert_match %r((window\.location = "/500\.html"</script></html>)$), response.body
        assert_match "Missing template test/doesntexist", output.rewind && output.read
        assert_stream_closed
      end
      assert response.body
      assert_stream_closed
    end

    def test_exception_handling_plain_text
      assert_raises(ActionView::MissingTemplate) do
        get :exception_in_view, format: :json
      end

      capture_log_output do |output|
        get :exception_in_view_after_commit, format: :json
        assert_equal "", response.body
        assert_match "Missing template test/doesntexist", output.rewind && output.read
        assert_stream_closed
      end
    end

    def test_exception_callback_when_committed
      capture_log_output do |output|
        get :exception_with_callback, format: "text/event-stream"

        assert_equal %(data: "500 Internal Server Error"\n\n), response.body
        assert_match "An exception occurred...", output.rewind && output.read
        assert_stream_closed
      end
    end

    def test_exception_in_controller_before_streaming
      assert_raises(ActionController::LiveStreamTest::Exception) do
        get :exception_in_controller, format: "text/event-stream"
      end
    end

    def test_bad_request_in_controller_before_streaming
      assert_raises(ActionController::BadRequest) do
        get :bad_request_error, format: "text/event-stream"
      end
    end

    def test_exceptions_raised_handling_exceptions_and_committed
      capture_log_output do |output|
        get :exception_in_exception_callback, format: "text/event-stream"
        assert_equal "", response.body
        assert_match "We need to go deeper", output.rewind && output.read
        assert_stream_closed
      end
    end

    def test_stale_without_etag
      get :with_stale
      assert_equal 200, response.status.to_i
    end

    def test_stale_with_etag
      @request.if_none_match = %(W/"#{ActiveSupport::Digest.hexdigest('123')}")
      get :with_stale
      assert_equal 304, response.status.to_i
    end

    def test_response_buffer_do_not_respond_to_to_ary
      get :basic_stream
      # `response.to_a` wraps the response with RackBody.
      # RackBody is the body we return to Rack.
      # Therefore we want to assert directly on it.
      # The Rack spec requires bodies that cannot be
      # buffered to return false to `respond_to?(:to_ary)`
      assert_not response.to_a.last.respond_to? :to_ary
    end
  end

  class LiveControllerThreadTest < ActionController::TestCase
    class TestController < ActionController::Base
      include ActionController::Live

      def greet
        response.headers["Content-Type"] = "text/event-stream"
        %w{ hello world }.each do |word|
          response.stream.write word
        end
        response.stream.close
      end
    end

    tests TestController

    def test_thread_locals_do_not_get_reset_in_test_environment
      Thread.current[:setting] = "aaron"

      get :greet

      assert_equal "aaron", Thread.current[:setting]
    end
  end

  class BufferTest < ActionController::TestCase
    def test_nil_callback
      buf = ActionController::Live::Buffer.new nil
      assert buf.call_on_error
    end
  end
end

class LiveStreamRouterTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    include ActionController::Live

    def index
      response.headers["Content-Type"] = "text/event-stream"
      sse = SSE.new(response.stream)
      sse.write("{\"name\":\"John\"}")
      sse.write(name: "Ryan")
    ensure
      sse.close
    end
  end

  def self.call(env)
    routes.call(env)
  end

  def self.routes
    @routes ||= ActionDispatch::Routing::RouteSet.new
  end

  routes.draw do
    get "/test" => "live_stream_router_test/test#index"
  end

  def app
    self.class
  end

  test "streaming served through the router" do
    get "/test"

    assert_response :ok
    assert_match(/data: {"name":"John"}/, response.body)
    assert_match(/data: {"name":"Ryan"}/, response.body)
  end
end
