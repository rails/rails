# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/event_reporter_assertions"
require "action_controller/structured_event_subscriber"

require "active_support/core_ext/object/with"

module ActionController
  class StructuredEventSubscriberTest < ActionController::TestCase
    module Another
      class StructuredEventSubscribersController < ActionController::Base
        rescue_from StandardError do |exception|
          head 500
        end

        def show
          head :ok
        end

        def redirector
          redirect_to "http://foo.bar/"
        end

        def data_sender
          send_data "cool data", filename: "file.txt"
        end

        def file_sender
          send_file File.expand_path("company.rb", FIXTURE_LOAD_PATH)
        end

        def filterable_redirector
          redirect_to "http://secret.foo.bar/"
        end

        def unpermitted_parameters
          params.permit(:name)
          render plain: "OK"
        end

        def with_fragment_cache
          render inline: "<%= cache('foo'){ 'bar' } %>"
        end

        def raise_error
          raise StandardError, "Something went wrong"
        end

        def open_redirector
          redirect_to "example.com"
        end
      end
    end

    tests Another::StructuredEventSubscribersController

    include ActiveSupport::Testing::EventReporterAssertions

    def setup
      @original_action_on_unpermitted_parameters = ActionController::Parameters.action_on_unpermitted_parameters
      ActionController::Parameters.action_on_unpermitted_parameters = :log
    end

    def teardown
      ActionController::Parameters.action_on_unpermitted_parameters = @original_action_on_unpermitted_parameters
    end

    def test_start_processing
      assert_event_reported("action_controller.request_started", payload: {
        controller: Another::StructuredEventSubscribersController.name,
        action: "show",
        format: "HTML"
      }) do
        get :show
      end
    end

    def test_start_processing_as_json
      assert_event_reported("action_controller.request_started", payload: {
        controller: Another::StructuredEventSubscribersController.name,
        action: "show",
        format: "JSON"
      }) do
        get :show, format: "json"
      end
    end

    def test_start_processing_with_parameters
      assert_event_reported("action_controller.request_started", payload: {
        controller: Another::StructuredEventSubscribersController.name,
        action: "show",
        params: { "id" => "10" }
      }) do
        get :show, params: { id: "10" }
      end
    end

    def test_process_action
      event = assert_event_reported("action_controller.request_completed", payload: {
        controller: Another::StructuredEventSubscribersController.name,
        action: "show",
        status: 200,
      }) do
        get :show
      end

      assert event[:payload][:duration_ms].is_a?(Numeric)
    end

    def test_redirect
      assert_event_reported("action_controller.redirected", payload: { location: "http://foo.bar/" }) do
        get :redirector
      end
    end

    def test_send_data
      event = assert_event_reported("action_controller.data_sent", payload: {
        filename: "file.txt"
      }) do
        get :data_sender
      end

      assert event[:payload][:duration_ms].is_a?(Numeric)
    end

    def test_send_file
      event = assert_event_reported("action_controller.file_sent", payload: {
        path: /company\.rb/
      }) do
        get :file_sender
      end

      assert event[:payload][:duration_ms].is_a?(Numeric)
    end

    def test_unpermitted_parameters
      with_debug_event_reporting do
        assert_event_reported("action_controller.unpermitted_parameters", payload: {
          unpermitted_keys: ["age"],
          context: {
            params: {
              "name" => "John",
              "age" => "30",
              "controller" => "action_controller/structured_event_subscriber_test/another/structured_event_subscribers",
              "action" => "unpermitted_parameters",
            },
            controller: Another::StructuredEventSubscribersController.name,
            action: "unpermitted_parameters"
          }
        }) do
          post :unpermitted_parameters, params: { name: "John", age: 30 }
        end
      end
    end

    def test_rescue_from_callback
      assert_event_reported("action_controller.rescue_from_handled", payload: {
        exception_class: "StandardError",
        exception_message: "Something went wrong"
      }) do
        get :raise_error
      end
    end

    def test_fragment_cache
      original_enable_fragment_cache_logging = ActionController::Base.enable_fragment_cache_logging
      ActionController::Base.enable_fragment_cache_logging = true
      cache_path = Dir.mktmpdir(%w[tmp cache])
      @controller.cache_store = :file_store, cache_path

      assert_event_reported("action_controller.fragment_cache", payload: {
        method: "read_fragment",
        key: "views/foo"
      }) do
        assert_event_reported("action_controller.fragment_cache", payload: {
          method: "write_fragment",
          key: "views/foo"
        }) do
          get :with_fragment_cache
        end
      end
    ensure
      ActionController::Base.enable_fragment_cache_logging = original_enable_fragment_cache_logging
      FileUtils.rm_rf(cache_path)
    end

    def test_open_redirect
      ActionController::Base.with(action_on_open_redirect: :notify) do
        event = assert_event_reported("action_controller.open_redirect", payload: {
          location: "http://test.hostexample.com",
          request_method: "GET",
          request_path: "/action_controller/structured_event_subscriber_test/another/structured_event_subscribers/open_redirector"
        }) do
          get :open_redirector
        end

        assert(event[:payload][:stacktrace].find { |line| line.include?("structured_event_subscriber_test.rb:51") })
      end
    end
  end
end
