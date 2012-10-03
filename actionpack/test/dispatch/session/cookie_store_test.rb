require 'abstract_unit'
require 'stringio'

class CookieStoreTest < ActionDispatch::IntegrationTest
  SessionKey = '_myapp_session'
  SessionSecret = 'b3c631c314c0bbca50c1b2843150fe33'

  Verifier = ActiveSupport::MessageVerifier.new(SessionSecret, :digest => 'SHA1')
  SignedBar = Verifier.generate(:foo => "bar", :session_id => SecureRandom.hex(16))

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

    def get_class_after_reset_session
      reset_session
      render :text => "class: #{session.class}"
    end

    def call_session_clear
      session.clear
      head :ok
    end

    def call_reset_session
      reset_session
      head :ok
    end

    def raise_data_overflow
      session[:foo] = 'bye!' * 1024
      head :ok
    end

    def change_session_id
      request.session_options[:id] = nil
      get_session_id
    end

    def renew_session_id
      request.session_options[:renew] = true
      head :ok
    end
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
      assert_equal "id: #{session_id}", response.body, "should be able to read session id without accessing the session hash"
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

  def test_does_not_set_secure_cookies_over_http
    with_test_route_set(:secure => true) do
      get '/set_session_value'
      assert_response :success
      assert_equal nil, headers['Set-Cookie']
    end
  end

  def test_properly_renew_cookies
    with_test_route_set do
      get '/set_session_value'
      get '/persistent_session_id'
      session_id = response.body
      get '/renew_session_id'
      get '/persistent_session_id'
      assert_not_equal response.body, session_id
    end
  end

  def test_does_set_secure_cookies_over_https
    with_test_route_set(:secure => true) do
      get '/set_session_value', nil, 'HTTPS' => 'on'
      assert_response :success
      assert_equal "_myapp_session=#{response.body}; path=/; secure; HttpOnly",
        headers['Set-Cookie']
    end
  end

  # {:foo=>#<SessionAutoloadTest::Foo bar:"baz">, :session_id=>"ce8b0752a6ab7c7af3cdb8a80e6b9e46"}
  SignedSerializedCookie = "BAh7BzoIZm9vbzodU2Vzc2lvbkF1dG9sb2FkVGVzdDo6Rm9vBjoJQGJhciIIYmF6Og9zZXNzaW9uX2lkIiVjZThiMDc1MmE2YWI3YzdhZjNjZGI4YTgwZTZiOWU0Ng==--2bf3af1ae8bd4e52b9ac2099258ace0c380e601c"

  def test_deserializes_unloaded_classes_on_get_id
    with_test_route_set do
      with_autoload_path "session_autoload_test" do
        cookies[SessionKey] = SignedSerializedCookie
        get '/get_session_id'
        assert_response :success
        assert_equal 'id: ce8b0752a6ab7c7af3cdb8a80e6b9e46', response.body, "should auto-load unloaded class"
      end
    end
  end

  def test_deserializes_unloaded_classes_on_get_value
    with_test_route_set do
      with_autoload_path "session_autoload_test" do
        cookies[SessionKey] = SignedSerializedCookie
        get '/get_session_value'
        assert_response :success
        assert_equal 'foo: #<SessionAutoloadTest::Foo bar:"baz">', response.body, "should auto-load unloaded class"
      end
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
      assert_not_nil session_payload
      assert_not_equal session_payload, cookies[SessionKey]

      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: nil', response.body
    end
  end

  def test_class_type_after_session_reset
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert_equal "_myapp_session=#{response.body}; path=/; HttpOnly",
        headers['Set-Cookie']

      get '/get_class_after_reset_session'
      assert_response :success
      assert_not_equal [], headers['Set-Cookie']
      assert_equal 'class: ActionDispatch::Request::Session', response.body
    end
  end

  def test_getting_from_nonexistent_session
    with_test_route_set do
      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: nil', response.body
      assert_nil headers['Set-Cookie'], "should only create session on write, not read"
    end
  end

  def test_setting_session_value_after_session_clear
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert_equal "_myapp_session=#{response.body}; path=/; HttpOnly",
        headers['Set-Cookie']

      get '/call_session_clear'
      assert_response :success

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

  def test_setting_session_id_to_nil_is_respected
    with_test_route_set do
      cookies[SessionKey] = SignedBar

      get "/get_session_id"
      sid = response.body
      assert_equal sid.size, 36

      get "/change_session_id"
      assert_not_equal sid, response.body
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
      assert_match(/domain=example\.es/, headers['Set-Cookie'])
      headers['Set-Cookie']
    end
  end

  def test_session_store_without_domain
    with_test_route_set do
      get '/set_session_value'
      assert_no_match(/domain\=/, headers['Set-Cookie'])
    end
  end

  def test_session_store_with_nil_domain
    with_test_route_set(:domain => nil) do
      get '/set_session_value'
      assert_no_match(/domain\=/, headers['Set-Cookie'])
    end
  end

  def test_session_store_with_all_domains
    with_test_route_set(:domain => :all) do
      get '/set_session_value'
      assert_match(/domain=\.example\.com/, headers['Set-Cookie'])
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
        set.draw do
          get ':action', :to => ::CookieStoreTest::TestController
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
