require 'abstract_unit'

class WebServiceTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def assign_parameters
      if params[:full]
        render :text => dump_params_keys
      else
        render :text => (params.keys - ['controller', 'action']).sort.join(", ")
      end
    end

    def dump_params_keys(hash = params)
      hash.keys.sort.inject("") do |s, k|
        value = hash[k]
        value = Hash === value ? "(#{dump_params_keys(value)})" : ""
        s << ", " unless s.empty?
        s << "#{k}#{value}"
      end
    end
  end

  def setup
    @controller = TestController.new
    @integration_session = nil
  end

  def test_check_parameters
    with_test_route_set do
      get "/"
      assert_equal '', @controller.response.body
    end
  end

  def test_post_json
    with_test_route_set do
      post "/", '{"entry":{"summary":"content..."}}', 'CONTENT_TYPE' => 'application/json'

      assert_equal 'entry', @controller.response.body
      assert @controller.params.has_key?(:entry)
      assert_equal 'content...', @controller.params["entry"]['summary']
    end
  end

  def test_put_json
    with_test_route_set do
      put "/", '{"entry":{"summary":"content..."}}', 'CONTENT_TYPE' => 'application/json'

      assert_equal 'entry', @controller.response.body
      assert @controller.params.has_key?(:entry)
      assert_equal 'content...', @controller.params["entry"]['summary']
    end
  end

  def test_register_and_use_json_simple
    with_test_route_set do
      with_params_parsers Mime::JSON => Proc.new { |data| JSON.parse(data)['request'].with_indifferent_access } do
        post "/", '{"request":{"summary":"content...","title":"JSON"}}',
          'CONTENT_TYPE' => 'application/json'

        assert_equal 'summary, title', @controller.response.body
        assert @controller.params.has_key?(:summary)
        assert @controller.params.has_key?(:title)
        assert_equal 'content...', @controller.params["summary"]
        assert_equal 'JSON', @controller.params["title"]
      end
    end
  end

  def test_use_json_with_empty_request
    with_test_route_set do
      assert_nothing_raised { post "/", "", 'CONTENT_TYPE' => 'application/json' }
      assert_equal '', @controller.response.body
    end
  end

  def test_dasherized_keys_as_json
    with_test_route_set do
      post "/?full=1", '{"first-key":{"sub-key":"..."}}', 'CONTENT_TYPE' => 'application/json'
      assert_equal 'action, controller, first-key(sub-key), full', @controller.response.body
      assert_equal "...", @controller.params['first-key']['sub-key']
    end
  end

  private
    def with_params_parsers(parsers = {})
      old_session = @integration_session
      @app = ActionDispatch::ParamsParser.new(app.routes, parsers)
      reset!
      yield
    ensure
      @integration_session = old_session
    end

    def with_test_route_set
      with_routing do |set|
        set.draw do
          match '/', :to => 'web_service_test/test#assign_parameters', :via => :all
        end
        yield
      end
    end
end
