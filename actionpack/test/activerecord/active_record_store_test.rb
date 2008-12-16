require 'active_record_unit'

class ActiveRecordStoreTest < ActionController::IntegrationTest
  DispatcherApp = ActionController::Dispatcher.new
  SessionApp = ActiveRecord::SessionStore.new(DispatcherApp,
                :key => '_session_id')
  SessionAppWithFixation = ActiveRecord::SessionStore.new(DispatcherApp,
                            :key => '_session_id', :cookie_only => false)

  class TestController < ActionController::Base
    def no_session_access
      head :ok
    end

    def set_session_value
      session[:foo] = params[:foo] || "bar"
      head :ok
    end

    def get_session_value
      render :text => "foo: #{session[:foo].inspect}"
    end

    def rescue_action(e) raise end
  end

  def setup
    ActiveRecord::SessionStore.session_class.create_table!
    @integration_session = open_session(SessionApp)
  end

  def teardown
    ActiveRecord::SessionStore.session_class.drop_table!
  end

  def test_setting_and_getting_session_value
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "bar"', response.body

      get '/set_session_value', :foo => "baz"
      assert_response :success
      assert cookies['_session_id']

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "baz"', response.body
    end
  end

  def test_getting_nil_session_value
    with_test_route_set do
      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: nil', response.body
    end
  end

  def test_prevents_session_fixation
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "bar"', response.body
      session_id = cookies['_session_id']
      assert session_id

      reset!

      get '/set_session_value', :_session_id => session_id, :foo => "baz"
      assert_response :success
      assert_equal nil, cookies['_session_id']

      get '/get_session_value', :_session_id => session_id
      assert_response :success
      assert_equal 'foo: nil', response.body
      assert_equal nil, cookies['_session_id']
    end
  end

  def test_allows_session_fixation
    @integration_session = open_session(SessionAppWithFixation)

    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert cookies['_session_id']

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "bar"', response.body
      session_id = cookies['_session_id']
      assert session_id

      reset!
      @integration_session = open_session(SessionAppWithFixation)

      get '/set_session_value', :_session_id => session_id, :foo => "baz"
      assert_response :success
      assert_equal session_id, cookies['_session_id']

      get '/get_session_value', :_session_id => session_id
      assert_response :success
      assert_equal 'foo: "baz"', response.body
      assert_equal session_id, cookies['_session_id']
    end
  end

  private
    def with_test_route_set
      with_routing do |set|
        set.draw do |map|
          map.with_options :controller => "active_record_store_test/test" do |c|
            c.connect "/:action"
          end
        end
        yield
      end
    end
end
