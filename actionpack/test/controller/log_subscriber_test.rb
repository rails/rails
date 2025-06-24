# frozen_string_literal: true

require "abstract_unit"
require "active_support/log_subscriber/test_helper"
require "action_controller/log_subscriber"

module Another
  class LogSubscribersController < ActionController::Base
    wrap_parameters :person, include: :name, format: :json

    class SpecialException < Exception
    end

    rescue_from SpecialException do
      head 406
    end

    before_action :redirector, only: :never_executed

    def never_executed
    end

    def show
      head :ok
    end

    def redirector
      redirect_to "http://foo.bar/"
    end

    def filterable_redirector
      redirect_to "http://secret.foo.bar/"
    end

    def filterable_redirector_with_params
      redirect_to "http://secret.foo.bar?username=repinel&password=1234"
    end

    def filterable_redirector_bad_uri
      redirect_to " s:/invalid-string0uri"
    end

    def data_sender
      send_data "cool data", filename: "file.txt"
    end

    def file_sender
      send_file File.expand_path("company.rb", FIXTURE_LOAD_PATH)
    end

    def with_fragment_cache
      render inline: "<%= cache('foo'){ 'bar' } %>"
    end

    def with_fragment_cache_and_percent_in_key
      render inline: "<%= cache('foo%bar'){ 'Contains % sign in key' } %>"
    end

    def with_fragment_cache_if_with_true_condition
      render inline: "<%= cache_if(true, 'foo') { 'bar' } %>"
    end

    def with_fragment_cache_if_with_false_condition
      render inline: "<%= cache_if(false, 'foo') { 'bar' } %>"
    end

    def with_fragment_cache_unless_with_false_condition
      render inline: "<%= cache_unless(false, 'foo') { 'bar' } %>"
    end

    def with_fragment_cache_unless_with_true_condition
      render inline: "<%= cache_unless(true, 'foo') { 'bar' } %>"
    end

    def with_throw
      throw :halt
    end

    def with_exception
      raise Exception
    end

    def with_rescued_exception
      raise SpecialException
    end

    def with_action_not_found
      raise AbstractController::ActionNotFound
    end

    def append_info_to_payload(payload)
      super
      payload[:test_key] = "test_value"
      @last_payload = payload
    end

    attr_reader :last_payload
  end
end

class ACLogSubscriberTest < ActionController::TestCase
  tests Another::LogSubscribersController
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super
    ActionController::Base.enable_fragment_cache_logging = true

    @old_logger = ActionController::Base.logger

    @cache_path = Dir.mktmpdir(%w[tmp cache])
    @controller.cache_store = :file_store, @cache_path
    @controller.config.perform_caching = true
    ActionController::LogSubscriber.attach_to :action_controller
  end

  def teardown
    super
    ActiveSupport::LogSubscriber.log_subscribers.clear
    FileUtils.rm_rf(@cache_path)
    ActionController::Base.logger = @old_logger
    ActionController::Base.enable_fragment_cache_logging = true
  end

  def set_logger(logger)
    ActionController::Base.logger = logger
  end

  def test_start_processing
    get :show
    wait
    assert_equal 2, logs.size
    assert_equal "Processing by Another::LogSubscribersController#show as HTML", logs.first
  end

  def test_start_processing_as_json
    get :show, format: "json"
    wait
    assert_equal 2, logs.size
    assert_equal "Processing by Another::LogSubscribersController#show as JSON", logs.first
  end

  def test_start_processing_as_non_exten
    get :show, format: "noext"
    wait
    assert_equal 2, logs.size
    assert_equal "Processing by Another::LogSubscribersController#show as */*", logs.first
  end

  def test_halted_callback
    get :never_executed
    wait
    assert_equal 4, logs.size
    assert_equal "Filter chain halted as :redirector rendered or redirected", logs.third
  end

  def test_process_action
    get :show
    wait
    assert_equal 2, logs.size
    assert_match(/Completed/, logs.last)
    assert_match(/200 OK/, logs.last)
  end

  def test_process_action_without_parameters
    get :show
    wait
    assert_nil logs.detect { |l| /Parameters/.match?(l) }
  end

  def test_process_action_with_parameters
    get :show, params: { id: "10" }
    wait

    assert_equal 3, logs.size
    assert_equal "Parameters: #{{ "id" => "10" }}", logs[1]
  end

  def test_multiple_process_with_parameters
    get :show, params: { id: "10" }
    get :show, params: { id: "20" }

    wait

    assert_equal 6, logs.size
    assert_equal "Parameters: #{{ "id" => "10" }}", logs[1]
    assert_equal "Parameters: #{{ "id" => "20" }}", logs[4]
  end

  def test_process_action_with_wrapped_parameters
    @request.env["CONTENT_TYPE"] = "application/json"
    post :show, params: { id: "10", name: "jose" }
    wait

    assert_equal 3, logs.size
    assert_match({ "person" => { "name" => "jose" } }.inspect[1..-2], logs[1])
  end

  def test_process_action_with_view_runtime
    get :show
    wait
    assert_match(/Completed 200 OK in \d+ms/, logs[1])
  end

  def test_process_action_with_path
    @request.env["action_dispatch.parameter_filter"] = [:password]
    get :show, params: { password: "test" }
    wait
    assert_match(/\/show\?password=\[FILTERED\]/, @controller.last_payload[:path])
  end

  def test_process_action_with_throw
    catch(:halt) do
      get :with_throw
      wait
    end
    assert_match(/Completed   in \d+ms/, logs[1])
  end

  def test_append_info_to_payload_is_called_even_with_exception
    begin
      get :with_exception
      wait
    rescue Exception
    end

    assert_equal "test_value", @controller.last_payload[:test_key]
  end

  def test_process_action_headers
    get :show
    wait
    assert_equal "Rails Testing", @controller.last_payload[:headers]["User-Agent"]
  end

  def test_process_action_with_filter_parameters
    @request.env["action_dispatch.parameter_filter"] = [:lifo, :amount]

    get :show, params: {
      lifo: "Pratik", amount: "420", step: "1"
    }
    wait

    params = logs[1]
    assert_match({ "amount" => "[FILTERED]" }.inspect[1..-2], params)
    assert_match({ "lifo" => "[FILTERED]" }.inspect[1..-2], params)
    assert_match({ "step" => "1" }.inspect[1..-2], params)
  end

  def test_redirect_to
    get :redirector
    wait

    assert_equal 3, logs.size
    assert_equal "Redirected to http://foo.bar/", logs[1]
    assert_match(/Completed 302/, logs.last)
  end

  def test_filter_redirect_url_by_string
    @request.env["action_dispatch.redirect_filter"] = ["secret"]
    get :filterable_redirector
    wait

    assert_equal 3, logs.size
    assert_equal "Redirected to [FILTERED]", logs[1]
  end

  def test_filter_redirect_url_by_regexp
    @request.env["action_dispatch.redirect_filter"] = [/secret\.foo.+/]
    get :filterable_redirector
    wait

    assert_equal 3, logs.size
    assert_equal "Redirected to [FILTERED]", logs[1]
  end

  def test_does_not_filter_redirect_params_by_default
    get :filterable_redirector_with_params
    wait

    assert_equal 3, logs.size
    assert_equal "Redirected to http://secret.foo.bar?username=repinel&password=1234", logs[1]
  end

  def test_filter_redirect_params_by_string
    @request.env["action_dispatch.parameter_filter"] = ["password"]
    get :filterable_redirector_with_params
    wait

    assert_equal 3, logs.size
    assert_equal "Redirected to http://secret.foo.bar?username=repinel&password=[FILTERED]", logs[1]
  end

  def test_filter_redirect_params_by_regexp
    @request.env["action_dispatch.parameter_filter"] = [/pass.+/]
    get :filterable_redirector_with_params
    wait

    assert_equal 3, logs.size
    assert_equal "Redirected to http://secret.foo.bar?username=repinel&password=[FILTERED]", logs[1]
  end

  def test_filter_redirect_bad_uri
    @request.env["action_dispatch.parameter_filter"] = [/pass.+/]

    get :filterable_redirector_bad_uri
    wait

    assert_equal 3, logs.size
    assert_equal "Redirected to [FILTERED]", logs[1]
  end

  def test_send_data
    get :data_sender
    wait

    assert_equal 3, logs.size
    assert_match(/Sent data file\.txt/, logs[1])
  end

  def test_send_file
    get :file_sender
    wait

    assert_equal 3, logs.size
    assert_match(/Sent file/, logs[1])
    assert_match(/test\/fixtures\/company\.rb/, logs[1])
  end

  def test_with_fragment_cache
    get :with_fragment_cache
    wait

    assert_equal 4, logs.size
    assert_match(/Read fragment views\/foo/, logs[1])
    assert_match(/Write fragment views\/foo/, logs[2])
  end

  def test_with_fragment_cache_when_log_disabled
    ActionController::Base.enable_fragment_cache_logging = false
    get :with_fragment_cache
    wait

    assert_equal 2, logs.size
    assert_equal "Processing by Another::LogSubscribersController#with_fragment_cache as HTML", logs[0]
    assert_match(/Completed 200 OK in \d+ms/, logs[1])
    ActionController::Base.enable_fragment_cache_logging = true
  end

  def test_with_fragment_cache_if_with_true
    get :with_fragment_cache_if_with_true_condition
    wait

    assert_equal 4, logs.size
    assert_match(/Read fragment views\/foo/, logs[1])
    assert_match(/Write fragment views\/foo/, logs[2])
  end

  def test_with_fragment_cache_if_with_false
    get :with_fragment_cache_if_with_false_condition
    wait

    assert_equal 2, logs.size
    assert_no_match(/Read fragment views\/foo/, logs[1])
    assert_no_match(/Write fragment views\/foo/, logs[2])
  end

  def test_with_fragment_cache_unless_with_true
    get :with_fragment_cache_unless_with_true_condition
    wait

    assert_equal 2, logs.size
    assert_no_match(/Read fragment views\/foo/, logs[1])
    assert_no_match(/Write fragment views\/foo/, logs[2])
  end

  def test_with_fragment_cache_unless_with_false
    get :with_fragment_cache_unless_with_false_condition
    wait

    assert_equal 4, logs.size
    assert_match(/Read fragment views\/foo/, logs[1])
    assert_match(/Write fragment views\/foo/, logs[2])
  end

  def test_with_fragment_cache_and_percent_in_key
    get :with_fragment_cache_and_percent_in_key
    wait

    assert_equal 4, logs.size
    assert_match(/Read fragment views\/foo/, logs[1])
    assert_match(/Write fragment views\/foo/, logs[2])
  end

  def test_process_action_with_exception_includes_http_status_code
    begin
      get :with_exception
      wait
    rescue Exception
    end
    assert_equal 2, logs.size
    assert_match(/Completed 500/, logs.last)
  end

  def test_process_action_with_rescued_exception_includes_http_status_code
    get :with_rescued_exception
    wait

    assert_equal 2, logs.size
    assert_match(/Completed 406/, logs.last)
  end

  def test_process_action_with_with_action_not_found_logs_404
    begin
      get :with_action_not_found
      wait
    rescue AbstractController::ActionNotFound
    end

    assert_equal 2, logs.size
    assert_match(/Completed 404/, logs.last)
  end

  def logs
    @logs ||= @logger.logged(:info)
  end
end
