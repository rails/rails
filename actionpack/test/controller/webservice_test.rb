# frozen_string_literal: true

require 'abstract_unit'
require 'active_support/json/decoding'

class WebServiceTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def assign_parameters
      if params[:full]
        render plain: dump_params_keys
      else
        render plain: (params.keys - ['controller', 'action']).sort.join(', ')
      end
    end

    def dump_params_keys(hash = params)
      hash.keys.sort.each_with_object(+'') do |k, s|
        value = hash[k]

        if value.is_a?(Hash) || value.is_a?(ActionController::Parameters)
          value = "(#{dump_params_keys(value)})"
        else
          value = ''
        end

        s << ', ' unless s.empty?
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
      get '/'
      assert_equal '', @controller.response.body
    end
  end

  def test_post_json
    with_test_route_set do
      post '/',
        params: '{"entry":{"summary":"content..."}}',
        headers: { 'CONTENT_TYPE' => 'application/json' }

      assert_equal 'entry', @controller.response.body
      assert @controller.params.has_key?(:entry)
      assert_equal 'content...', @controller.params['entry']['summary']
    end
  end

  def test_put_json
    with_test_route_set do
      put '/',
        params: '{"entry":{"summary":"content..."}}',
        headers: { 'CONTENT_TYPE' => 'application/json' }

      assert_equal 'entry', @controller.response.body
      assert @controller.params.has_key?(:entry)
      assert_equal 'content...', @controller.params['entry']['summary']
    end
  end

  def test_register_and_use_json_simple
    with_test_route_set do
      with_params_parsers Mime[:json] => Proc.new { |data| ActiveSupport::JSON.decode(data)['request'].with_indifferent_access } do
        post '/',
          params: '{"request":{"summary":"content...","title":"JSON"}}',
          headers: { 'CONTENT_TYPE' => 'application/json' }

        assert_equal 'summary, title', @controller.response.body
        assert @controller.params.has_key?(:summary)
        assert @controller.params.has_key?(:title)
        assert_equal 'content...', @controller.params['summary']
        assert_equal 'JSON', @controller.params['title']
      end
    end
  end

  def test_use_json_with_empty_request
    with_test_route_set do
      assert_nothing_raised { post '/', headers: { 'CONTENT_TYPE' => 'application/json' } }
      assert_equal '', @controller.response.body
    end
  end

  def test_dasherized_keys_as_json
    with_test_route_set do
      post '/?full=1',
        params: '{"first-key":{"sub-key":"..."}}',
        headers: { 'CONTENT_TYPE' => 'application/json' }
      assert_equal 'action, controller, first-key(sub-key), full', @controller.response.body
      assert_equal '...', @controller.params['first-key']['sub-key']
    end
  end

  def test_parsing_json_doesnot_rescue_exception
    req = Class.new(ActionDispatch::Request) do
      def params_parsers
        { json: Proc.new { |data| raise Interrupt } }
      end

      def content_length; get_header('rack.input').length; end
    end.new('rack.input' => StringIO.new('{"title":"JSON"}}'), 'CONTENT_TYPE' => 'application/json')

    assert_raises(Interrupt) do
      req.request_parameters
    end
  end

  private
    def with_params_parsers(parsers = {})
      old_session = @integration_session
      original_parsers = ActionDispatch::Request.parameter_parsers
      ActionDispatch::Request.parameter_parsers = original_parsers.merge parsers
      reset!
      yield
    ensure
      ActionDispatch::Request.parameter_parsers = original_parsers
      @integration_session = old_session
    end

    def with_test_route_set
      with_routing do |set|
        set.draw do
          match '/', to: 'web_service_test/test#assign_parameters', via: :all
        end
        yield
      end
    end
end
