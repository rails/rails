require 'abstract_unit'

# You need to start a memcached server inorder to run these tests
class MemCacheStoreTest < ActionController::IntegrationTest
  class TestController < ActionController::Base
    def no_session_access
      head :ok
    end

    def set_session_value
      session[:foo] = "bar"
      head :ok
    end

    def get_session_value
      render :text => "foo: #{session[:foo].inspect}"
    end

    def get_session_id
      render :text => "foo: #{session[:foo].inspect}; id: #{request.session_options[:id]}"
    end

    def call_reset_session
      reset_session
      head :ok
    end

    def rescue_action(e) raise end
  end

  begin
    DispatcherApp = ActionController::Dispatcher.new
    MemCacheStoreApp = ActionController::Session::MemCacheStore.new(
                         DispatcherApp, :key => '_session_id')


    def setup
      @integration_session = open_session(MemCacheStoreApp)
    end

    def test_setting_and_getting_session_value
      with_test_route_set do
        get '/set_session_value'
        assert_response :success
        assert cookies['_session_id']

        get '/get_session_value'
        assert_response :success
        assert_equal 'foo: "bar"', response.body
      end
    end

    def test_getting_nil_session_value
      with_test_route_set do
        get '/get_session_value'
        assert_response :success
        assert_equal 'foo: nil', response.body
      end
    end

    def test_getting_session_id
      with_test_route_set do
        get '/set_session_value'
        assert_response :success
        assert cookies['_session_id']
        session_id = cookies['_session_id']

        get '/get_session_id'
        assert_response :success
        assert_equal "foo: \"bar\"; id: #{session_id}", response.body
      end
    end

    def test_prevents_session_fixation
      with_test_route_set do
        get '/get_session_value'
        assert_response :success
        assert_equal 'foo: nil', response.body
        session_id = cookies['_session_id']

        reset!

        get '/set_session_value', :_session_id => session_id
        assert_response :success
        assert_equal nil, cookies['_session_id']
      end
    end

    def test_setting_session_value_after_session_reset
      with_test_route_set do
        get '/set_session_value'
        assert_response :success
        assert cookies['_session_id']

        get '/call_reset_session'
        assert_response :success
        assert_not_equal [], headers['Set-Cookie']

        get '/get_session_value'
        assert_response :success
        assert_equal 'foo: nil', response.body
      end
    end
  rescue LoadError, RuntimeError
    $stderr.puts "Skipping MemCacheStoreTest tests. Start memcached and try again."
  end

  private
    def with_test_route_set
      with_routing do |set|
        set.draw do |map|
          map.with_options :controller => "mem_cache_store_test/test" do |c|
            c.connect "/:action"
          end
        end
        yield
      end
    end
end
