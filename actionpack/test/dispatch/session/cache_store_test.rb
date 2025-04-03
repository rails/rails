# frozen_string_literal: true

require "abstract_unit"

class CacheStoreTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def no_session_access
      head :ok
    end

    def set_session_value
      session[:foo] = "bar"
      head :ok
    end

    def set_serialized_session_value
      session[:foo] = SessionAutoloadTest::Foo.new
      head :ok
    end

    def get_session_value
      render plain: "foo: #{session[:foo].inspect}"
    end

    def get_session_id
      render plain: "#{request.session.id.public_id}"
    end

    def call_reset_session
      session[:bar]
      reset_session
      session[:bar] = "baz"
      head :ok
    end
  end

  def test_setting_and_getting_session_value
    with_test_route_set do
      get "/set_session_value"
      assert_response :success
      assert cookies["_session_id"]

      get "/get_session_value"
      assert_response :success
      assert_equal 'foo: "bar"', response.body
    end
  end

  def test_getting_nil_session_value
    with_test_route_set do
      get "/get_session_value"
      assert_response :success
      assert_equal "foo: nil", response.body
    end
  end

  def test_getting_session_value_after_session_reset
    with_test_route_set do
      get "/set_session_value"
      assert_response :success
      assert cookies["_session_id"]
      session_cookie = cookies.get_cookie("_session_id")

      get "/call_reset_session"
      assert_response :success
      assert_not_equal [], headers["Set-Cookie"]

      cookies << session_cookie # replace our new session_id with our old, pre-reset session_id

      get "/get_session_value"
      assert_response :success
      assert_equal "foo: nil", response.body, "data for this session should have been obliterated from cache"
    end
  end

  def test_getting_from_nonexistent_session
    with_test_route_set do
      get "/get_session_value"
      assert_response :success
      assert_equal "foo: nil", response.body
      assert_nil cookies["_session_id"], "should only create session on write, not read"
    end
  end

  def test_setting_session_value_after_session_reset
    with_test_route_set do
      get "/set_session_value"
      assert_response :success
      assert cookies["_session_id"]
      session_id = cookies["_session_id"]

      get "/call_reset_session"
      assert_response :success
      assert_not_equal [], headers["Set-Cookie"]
      assert_not_nil headers["Set-Cookie"]

      get "/get_session_value"
      assert_response :success
      assert_equal "foo: nil", response.body

      get "/get_session_id"
      assert_response :success
      assert_not_equal session_id, response.body
    end
  end

  def test_getting_session_id
    with_test_route_set do
      get "/set_session_value"
      assert_response :success
      assert cookies["_session_id"]
      session_id = cookies["_session_id"]

      get "/get_session_id"
      assert_response :success
      assert_equal session_id, response.body, "should be able to read session id without accessing the session hash"
    end
  end

  def test_deserializes_unloaded_class
    with_test_route_set do
      with_autoload_path "session_autoload_test" do
        get "/set_serialized_session_value"
        assert_response :success
        assert cookies["_session_id"]
      end
      with_autoload_path "session_autoload_test" do
        get "/get_session_id"
        assert_response :success
      end
      with_autoload_path "session_autoload_test" do
        get "/get_session_value"
        assert_response :success
        assert_equal 'foo: #<SessionAutoloadTest::Foo bar:"baz">', response.body, "should auto-load unloaded class"
      end
    end
  end

  def test_doesnt_write_session_cookie_if_session_id_is_already_exists
    with_test_route_set do
      get "/set_session_value"
      assert_response :success
      assert cookies["_session_id"]

      get "/get_session_value"
      assert_response :success
      assert_nil headers["Set-Cookie"], "should not resend the cookie again if session_id cookie is already exists"
    end
  end

  def test_prevents_session_fixation
    with_test_route_set do
      sid = Rack::Session::SessionId.new("0xhax")
      assert_nil @cache.read("_session_id:#{sid.private_id}")

      cookies["_session_id"] = sid.public_id
      get "/set_session_value"

      assert_response :success
      assert_not_equal sid.public_id, cookies["_session_id"]
      assert_nil @cache.read("_session_id:#{sid.private_id}")
      assert_equal(
        { "foo" => "bar" },
        @cache.read("_session_id:#{Rack::Session::SessionId.new(cookies['_session_id']).private_id}")
      )
    end
  end

  def test_can_read_session_with_legacy_id
    with_test_route_set do
      get "/set_session_value"
      assert_response :success
      assert cookies["_session_id"]

      sid = Rack::Session::SessionId.new(cookies["_session_id"])
      session = @cache.read("_session_id:#{sid.private_id}")
      @cache.delete("_session_id:#{sid.private_id}")
      @cache.write("_session_id:#{sid.public_id}", session)

      get "/get_session_value"
      assert_response :success
      assert_equal 'foo: "bar"', response.body
    end
  end

  def test_drop_session_in_the_legacy_id_as_well
    with_test_route_set do
      get "/set_session_value"
      assert_response :success
      assert cookies["_session_id"]

      sid = Rack::Session::SessionId.new(cookies["_session_id"])
      session = @cache.read("_session_id:#{sid.private_id}")
      @cache.delete("_session_id:#{sid.private_id}")
      @cache.write("_session_id:#{sid.public_id}", session)

      get "/call_reset_session"
      assert_response :success
      assert_not_equal [], headers["Set-Cookie"]

      assert_nil @cache.read("_session_id:#{sid.private_id}")
      assert_nil @cache.read("_session_id:#{sid.public_id}")
    end
  end

  def test_doesnt_generate_same_sid_with_check_collisions
    cache_store_options({ check_collisions: true })

    expected_values = [
      +"eed45f3da20b5c4da3bc3b160f996315",
      +"eed45f3da20b5c4da3bc3b160f996315",
      +"eed45f3da20b5c4da3bc3b160f996316",
    ]
    counter = -1
    hex_generator = proc do
      counter += 1
      expected_values[counter]
    end

    SecureRandom.stub(:hex, hex_generator) do
      with_test_route_set do
        get "/set_session_value"
        assert_response :success
        assert cookies["_session_id"]

        first_sid = Rack::Session::SessionId.new(cookies["_session_id"])
        assert_equal expected_values[0], first_sid.public_id

        cookies.delete("_session_id")

        get "/set_session_value"
        assert_response :success
        assert cookies["_session_id"]

        second_sid = Rack::Session::SessionId.new(cookies["_session_id"])
        assert_equal expected_values[2], second_sid.public_id
      end
    end
  end

  private
    def cache_store_options(options = {})
      @cache_store_options ||= options
    end

    def app
      @app ||= self.class.build_app do |middleware|
        @cache = ActiveSupport::Cache::MemoryStore.new
        middleware.use ActionDispatch::Session::CacheStore, key: "_session_id", cache: @cache, **cache_store_options
        middleware.delete ActionDispatch::ShowExceptions
      end
    end

    def with_test_route_set
      with_routing do |set|
        set.draw do
          ActionDispatch.deprecator.silence do
            get ":action", to: ::CacheStoreTest::TestController
          end
        end

        yield
      end
    end
end
