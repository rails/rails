require 'abstract_unit'
require 'active_support/concurrency/latch'

module ActionController
  class SseServerTest < ActionController::TestCase

    # This is a fake controller used for testing purposes. It contains the
    # ActionController::ServerSentEvents module, as well as the module it
    # runs on, ActionController::Live.
    class TestController < ActionController::Base
      include ActionController::Live
      include ActionController::ServerSentEvents

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

    # Another fake controller, however, it doesn't contain the module
    # ActionController::Live.
    class TestControllerWithoutLive < ActionController::Base
      include ActionController::ServerSentEvents

      def self.controller_path
       'test_no_live'
      end

      def send_an_sse
        ActionController::ServerSentEvents.start_server
        ActionController::ServerSentEvents.subscribe(response)
        ActionController::ServerSentEvents.send_sse_hash({:data => "This is something I'm sending"})
      end
    end

    # A test response for sending SSEs over.
    class TestResponse < Live::Response
      def recycle!
        initialize
      end
    end

    tests TestController

    def test_text_rendering
      @controller = TestController.new
      get :render_text
      assert_equal 'zomg', @response.body
    end

    def test_server_sent_event_converts_hash_to_correct_payload
      data = "I only have 21 dollars in my pocket"
      name = "sse group"
      retry_time = "2"

      opts = {:name => name, :retry => retry_time}
      sse_object = ActionController::ServerSentEvents::ServerSentEvent.new(data, opts)

      assert_equal name, sse_object.name, "Should be able to access sse object's name attribute"
      assert_equal retry_time, sse_object.retry, "Should be able to access sse object's retry attribute"
      assert_equal data, sse_object.name, "Should be able to access sse object's data attribute"

      payload = sse_object.to_payload_hash
      assert_equal 4, payload.size, "The payload hash should contain 4 items"
      assert_equal name, payload[:name]
      assert_equal retry_time, payload[:retry]
      assert_equal data, payload[:data]
    end

    def test_sse_server_only_sends_data_when_there_is_a_subscriber
      response = TestResponse.new

      sse_data = "I bet this is awesome, dude"
      sse_server = ActionController::ServerSentEvents::SseServer.new
      sse_server.subscribe(response)
      sse_server.unsubscribe(response)
      sse_server.send_sse_hash({:data => sse_data})

      assert !sse_server.empty_queue?, "There exists data in the queue, so it shouldn't be empty"
      sse_server.start

      assert !sse_server.empty_queue?, "There is no subscriber on the queue, so it shouldn't be empty"
      sse_server.subscribe(response)
      assert sse_server.empty_queue?, "The server should have sent the sse to the response"

      sleep(0.1)
      response.stream.close
      result = response.body
      assert_match /^data: #{sse_data}$/, result
    end

    def test_stop_server_sets_continue_sending_variable_to_false
      sse_server = ActionController::ServerSentEvents::SseServer.new
      sse_server.start

      assert sse_server.empty_queue?, "Sse server should be initialized with an empty queue"
      assert sse_server.continue_sending, "Sse server should still be sending data"
      sse_server.stop
      assert !sse_server.continue_sending, "Stopping the sse server should stop data from getting sent"
    end

    def test_send_sses_via_the_server_sent_event_object
      data = "I only have 21 dollars in my pocket"
      name = "sse group"
      retry_time = "2"

      sse_server = ActionController::ServerSentEvents::SseServer.new
      sse_object = ActionController::ServerSentEvents::ServerSentEvent.new(data, {:name => name, :retry => retry_time})

      assert sse_server.empty_queue?, "Sse server should be initialized with an empty queue"
      assert
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
