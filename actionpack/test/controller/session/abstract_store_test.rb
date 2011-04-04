require 'abstract_unit'

# You need to start a memcached server inorder to run these tests
class AbstractStoreTest < ActionController::IntegrationTest
  SessionKey = '_myapp_session'
  DispatcherApp = ActionController::Dispatcher.new

  class TestController < ActionController::Base
    def get_session
      session[:test] = 'test'
      head :ok
    end
  end

  def test_expiry_after
    with_test_route_set(:expire_after => 5 * 60) do
      get 'get_session'
      assert_response :success
      assert_match /expires=\S+/, headers['Set-Cookie']
    end
  end

protected

  def with_test_route_set(options = {})
    with_routing do |set|
      set.draw do |map|
        map.with_options :controller => "abstract_store_test/test" do |c|
          c.connect "/:action"
        end
      end

      options = { :key => SessionKey, :secret => 'SessionSecret' }.merge!(options)
      @integration_session = open_session(TestStore.new(DispatcherApp, options))

      yield
    end
  end

  class TestStore < ActionController::Session::AbstractStore
    def initialize(app, options = {})
      super
      @_store = Hash.new({})
    end

  private

    def get_session(env, sid)
      sid ||= generate_sid
      session = @_store[sid]
      [sid, session]
    end

    def set_session(env, sid, session_data)
      @_store[sid] = session_data
    end

    def destroy(env)
      @_store.delete(sid)
    end
  end

end

