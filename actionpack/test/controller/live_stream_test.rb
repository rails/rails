require 'abstract_unit'
require 'active_support/concurrency/latch'

module ActionController
  class LiveStreamTest < ActionController::TestCase
    class TestController < ActionController::Base
      include ActionController::Live

      attr_accessor :latch, :tc

      def self.controller_path
        'test'
      end

      def render_text
        render :text => 'zomg'
      end

      def default_header
        response.stream.write "<html><body>hi</body></html>"
        response.stream.close
      end

      def basic_stream
        response.headers['Content-Type'] = 'text/event-stream'
        %w{ hello world }.each do |word|
          response.stream.write word
        end
        response.stream.close
      end

      def blocking_stream
        response.headers['Content-Type'] = 'text/event-stream'
        %w{ hello world }.each do |word|
          response.stream.write word
          latch.await
        end
        response.stream.close
      end

      def thread_locals
        tc.assert_equal 'aaron', Thread.current[:setting]
        tc.assert_not_equal Thread.current.object_id, Thread.current[:originating_thread]

        response.headers['Content-Type'] = 'text/event-stream'
        %w{ hello world }.each do |word|
          response.stream.write word
        end
        response.stream.close
      end
    end

    tests TestController

    class TestResponse < Live::Response
      def recycle!
        initialize
      end
    end

    def build_response
      TestResponse.new
    end

    def test_set_response!
      @controller.set_response!(@request)
      assert_kind_of(Live::Response, @controller.response)
      assert_equal @request, @controller.response.request
    end

    def test_write_to_stream
      @controller = TestController.new
      get :basic_stream
      assert_equal "helloworld", @response.body
      assert_equal 'text/event-stream', @response.headers['Content-Type']
    end

    def test_async_stream
      @controller.latch = ActiveSupport::Concurrency::Latch.new
      parts             = ['hello', 'world']

      @controller.request  = @request
      @controller.response = @response

      t = Thread.new(@response) { |resp|
        resp.stream.each do |part|
          assert_equal parts.shift, part
          ol = @controller.latch
          @controller.latch = ActiveSupport::Concurrency::Latch.new
          ol.release
        end
      }

      @controller.process :blocking_stream

      assert t.join
    end

    def test_thread_locals_get_copied
      @controller.tc = self
      Thread.current[:originating_thread] = Thread.current.object_id
      Thread.current[:setting]            = 'aaron'

      get :thread_locals
    end

    def test_live_stream_default_header
      @controller.request  = @request
      @controller.response = @response
      @controller.process :default_header
      _, headers, _ = @response.prepare!
      assert headers['Content-Type']
    end

    def test_render_text
      get :render_text
      assert_equal 'zomg', response.body
      assert response.stream.closed?, 'stream should be closed'
    end
  end
end
