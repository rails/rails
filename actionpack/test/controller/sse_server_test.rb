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
        start_serve do |client|
          client.send_sse_hash :data => "david"
        end
      end
    end

    class TestController2 < ActionController::Base
      include ActionController::Live
      include ActionController::ServerSentEvents
      extend ActionController::ServerSentEvents::ClassMethods

      def self.controller_path
        'test'
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
      assert_equal data, sse_object.data, "Should be able to access sse object's data attribute"

      payload = sse_object.to_payload_hash
      assert_equal 4, payload.size, "The payload hash should contain 4 items"
      assert_equal name, payload[:name]
      assert_equal retry_time, payload[:retry]
      assert_equal data, payload[:data]
    end

    def test_send_sse_will_push_data_to_queue
      client = ActionController::ServerSentEvents::SseClient.new
      client.instance_variable_set "@stopped", false
      client.send_sse_hash :data => "hello david", :id => "1234567"
      queue = client.instance_variable_get "@sse_queue"

      item = queue.pop true
      assert_equal "hello david", item[:data]
      assert_equal "1234567", item[:id]

      client.send_sse ActionController::ServerSentEvents::ServerSentEvent.new("This is David")
      item = queue.pop true
      assert_equal "This is David", item[:data]
    end


    def test_sse_client_will_send_data_to_response_stream
      response = TestResponse.new
      client = ActionController::ServerSentEvents::SseClient.new
      client.subscribe response

      t = Thread.new do
        client.start_serve
      end

      sleep(0.2)
      client.send_sse_hash :data => "david", :id => "123456"
      sleep(0.2)
      t.exit

      response.stream.close
      result = response.body
      assert_match /^id: 123456$/, result
      assert_match /^data: david$/, result
    end

    def test_sse_client_will_stop_serve_when_response_stream_closed
      response = TestResponse.new
      client = ActionController::ServerSentEvents::SseClient.new
      client.subscribe response
      io_err = false

      t = Thread.new do
        begin
          client.start_serve
        rescue IOError
          io_err = true
        end
      end

      sleep(0.2)
      client.send_sse_hash :data => "david"
      assert t.alive?

      response.stream.close
      client.send_sse_hash :data => "david2" # This will cause an exception
      sleep(0.2)
      assert !t.alive?
      assert io_err
    end

    def test_client_level_sse
      @controller = TestController.new
      get :send_an_sse

      sleep(0.1)  # Sleep so that the read queue has enough time to see the data
      response.stream.close
      result = response.body
      assert_match /^data: david$/, result
      assert_match /^id: \w+$/, result
    end

    def test_controller_level_sse
      @controller = TestController2.new

      Thread.new{
        begin
          get :sse_source
        rescue => e
          puts e
        end
      }

      sleep(0.3) # the controller level sse is volatile, so we wait client 
      TestController2.send_sse_hash :data => "david"
      sleep(0.3) # wait process
      response.stream.close
      result = response.body
      assert_match /^data: david$/, result
      assert_match /^id: \w+$/, result
    end
  end
end
