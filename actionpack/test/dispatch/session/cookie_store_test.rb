require 'abstract_unit'
require 'stringio'

class CookieStoreTest < ActionController::IntegrationTest
  SessionKey = '_myapp_session'
  SessionSecret = 'b3c631c314c0bbca50c1b2843150fe33'

  Verifier = ActiveSupport::MessageVerifier.new(SessionSecret, 'SHA1')
  SignedBar = Verifier.generate(:foo => "bar", :session_id => ActiveSupport::SecureRandom.hex(16))

  class TestController < ActionController::Base
    def no_session_access
      head :ok
    end

    def persistent_session_id
      render :text => session[:session_id]
    end

    def set_session_value
      session[:foo] = "bar"
      render :text => Rack::Utils.escape(Verifier.generate(session.to_hash))
    end

    def get_session_value
      render :text => "foo: #{session[:foo].inspect}"
    end

    def get_session_id
      render :text => "id: #{request.session_options[:id]}"
    end

    def call_reset_session
      reset_session
      head :ok
    end

    def raise_data_overflow
      session[:foo] = 'bye!' * 1024
      head :ok
    end

    def rescue_action(e) raise end
  end

  def test_raises_argument_error_if_missing_session_key
    assert_raise(ArgumentError, nil.inspect) {
      ActionDispatch::Session::CookieStore.new(nil,
        :key => nil, :secret => SessionSecret)
    }

    assert_raise(ArgumentError, ''.inspect) {
      ActionDispatch::Session::CookieStore.new(nil,
        :key => '', :secret => SessionSecret)
    }
  end

  def test_setting_session_value
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert_equal "_myapp_session=#{response.body}; path=/; HttpOnly",
        headers['Set-Cookie']
    end
  end

  def test_getting_session_value
    with_test_route_set do
      cookies[SessionKey] = SignedBar
      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "bar"', response.body
    end
  end

  def test_getting_session_id
    with_test_route_set do
      cookies[SessionKey] = SignedBar
      get '/persistent_session_id'
      assert_response :success
      assert_equal response.body.size, 32
      session_id = response.body

      get '/get_session_id'
      assert_response :success
      assert_equal "id: #{session_id}", response.body
    end
  end

  def test_disregards_tampered_sessions
    with_test_route_set do
      cookies[SessionKey] = "BAh7BjoIZm9vIghiYXI%3D--123456780"
      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: nil', response.body
    end
  end

  def test_close_raises_when_data_overflows
    with_test_route_set do
      assert_raise(ActionDispatch::Cookies::CookieOverflow) {
        get '/raise_data_overflow'
      }
    end
  end

  def test_doesnt_write_session_cookie_if_session_is_not_accessed
    with_test_route_set do
      get '/no_session_access'
      assert_response :success
      assert_equal nil, headers['Set-Cookie']
    end
  end

  def test_doesnt_write_session_cookie_if_session_is_unchanged
    with_test_route_set do
      cookies[SessionKey] = "BAh7BjoIZm9vIghiYXI%3D--" +
        "fef868465920f415f2c0652d6910d3af288a0367"
      get '/no_session_access'
      assert_response :success
      assert_equal nil, headers['Set-Cookie']
    end
  end

  def test_setting_session_value_after_session_reset
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      session_payload = response.body
      assert_equal "_myapp_session=#{response.body}; path=/; HttpOnly",
        headers['Set-Cookie']

      get '/call_reset_session'
      assert_response :success
      assert_not_equal [], headers['Set-Cookie']
      assert_not_equal session_payload, cookies[SessionKey]

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: nil', response.body
    end
  end

  def test_persistent_session_id
    with_test_route_set do
      cookies[SessionKey] = SignedBar
      get '/persistent_session_id'
      assert_response :success
      assert_equal response.body.size, 32
      session_id = response.body
      get '/persistent_session_id'
      assert_equal session_id, response.body
      reset!
      get '/persistent_session_id'
      assert_not_equal session_id, response.body
    end
  end

  def test_session_store_with_expire_after
    with_test_route_set(:expire_after => 5.hours) do
      # First request accesses the session
      time = Time.local(2008, 4, 24)
      Time.stubs(:now).returns(time)
      expected_expiry = (time + 5.hours).gmtime.strftime("%a, %d-%b-%Y %H:%M:%S GMT")

      cookies[SessionKey] = SignedBar

      get '/set_session_value'
      assert_response :success

      cookie_body = response.body
      assert_equal "_myapp_session=#{cookie_body}; path=/; expires=#{expected_expiry}; HttpOnly",
        headers['Set-Cookie']

      # Second request does not access the session
      time = Time.local(2008, 4, 25)
      Time.stubs(:now).returns(time)
      expected_expiry = (time + 5.hours).gmtime.strftime("%a, %d-%b-%Y %H:%M:%S GMT")

      get '/no_session_access'
      assert_response :success

      assert_equal "_myapp_session=#{cookie_body}; path=/; expires=#{expected_expiry}; HttpOnly",
        headers['Set-Cookie']
    end
  end

  def test_session_store_with_explicit_domain
    with_test_route_set(:domain => "example.es") do
      get '/set_session_value'
      assert_match /domain=example\.es/, headers['Set-Cookie']
      headers['Set-Cookie']
    end
  end
  
  def test_session_store_without_domain 
    with_test_route_set do
      get '/set_session_value'
      assert_no_match /domain\=/, headers['Set-Cookie']
    end
  end
  
  def test_session_store_with_nil_domain
    with_test_route_set(:domain => nil) do
      get '/set_session_value'
      assert_no_match /domain\=/, headers['Set-Cookie']
    end
  end
  
  def test_session_store_with_all_domains
    with_test_route_set(:domain => :all) do
      get '/set_session_value'
      assert_match /domain=\.example\.com/, headers['Set-Cookie']
    end
  end
  
  private

    # Overwrite get to send SessionSecret in env hash
    def get(path, parameters = nil, env = {})
      env["action_dispatch.secret_token"] ||= SessionSecret
      super
    end

    def with_test_route_set(options = {})
      with_routing do |set|
        set.draw do |map|
          match ':action', :to => ::CookieStoreTest::TestController
        end

        options = { :key => SessionKey }.merge!(options)

        @app = self.class.build_app(set) do |middleware|
          middleware.use ActionDispatch::Session::CookieStore, options
          middleware.delete "ActionDispatch::ShowExceptions"
        end

        yield
      end
    end
end
