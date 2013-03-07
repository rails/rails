require 'abstract_unit'
require 'active_support/concurrency/latch'

module ActionController
  class SseServerTest < ActionController::TestCase
    class TestController < ActionController::Base
      include ActionController::Live
      include ActionController::ServerSentEvents

      attr_accessor :latch, :tc

      def self.controller_path
        'test'
      end

      def render_text
        render :text => 'zomg'
      end

      def send_an_sse
        ActionController::ServerSentEvents.start_server
        ActionController::ServerSentEvents.subscribe(response)
        response.stream.write "hello"
        ActionController::ServerSentEvents.send_sse_hash({:data => "Hi my name is John"})
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

    def test_text_rendering
      @controller = TestController.new
      get :render_text
      assert_equal 'zomg', @response.body
    end

    def test_streaming_sses_in_response_stream
      response = TestResponse.new

      sse_data = "I'm sending an sse!"
      assert_raise(ArgumentError) { ActionController::ServerSentEvents.subscribe(response) }
      assert_raise(ArgumentError) { ActionController::ServerSentEvents.send_sse_hash({:data => sse_data}) }

      ActionController::ServerSentEvents.start_server
      ActionController::ServerSentEvents.subscribe(response)
      ActionController::ServerSentEvents.send_sse_hash({:data => sse_data})
      sleep(0.1)  # Sleep so that the read queue has enough time to see the data

      response.stream.close
      result = response.body
      assert_match /^id: \w+$/, result
      assert_match /^data: #{sse_data}$/, result
    ensure
      ActionController::ServerSentEvents.stop_server
    end

    def test_streaming_sses_through_controller_method
      @controller = TestController.new
      get :send_an_sse

      sleep(0.1)  # Sleep so that the read queue has enough time to see the data
      response.stream.close
      result = response.body
      assert_match /^data: Hi my name is John$/, result
      assert_match /^id: \w+$/, result
      assert_match /^hello$/, result
    ensure
      ActionController::ServerSentEvents.stop_server
    end
  end
end
