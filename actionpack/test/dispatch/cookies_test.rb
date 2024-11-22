# frozen_string_literal: true

require "abstract_unit"
require "openssl"
require "active_support/key_generator"
require "active_support/messages/rotation_configuration"

class CookieJarTest < ActiveSupport::TestCase
  attr_reader :request

  def setup
    @request = ActionDispatch::Request.empty
  end

  def test_fetch
    x = Object.new
    assert_not request.cookie_jar.key?("zzzzzz")
    assert_equal x, request.cookie_jar.fetch("zzzzzz", x)
    assert_not request.cookie_jar.key?("zzzzzz")
  end

  def test_fetch_exists
    x = Object.new
    request.cookie_jar["foo"] = "bar"
    assert_equal "bar", request.cookie_jar.fetch("foo", x)
  end

  def test_fetch_block
    x = Object.new
    assert_not request.cookie_jar.key?("zzzzzz")
    assert_equal x, request.cookie_jar.fetch("zzzzzz") { x }
  end

  def test_key_is_to_s
    request.cookie_jar["foo"] = "bar"
    assert_equal "bar", request.cookie_jar.fetch(:foo)
  end

  def test_to_hash
    request.cookie_jar["foo"] = "bar"
    assert_equal({ "foo" => "bar" }, request.cookie_jar.to_hash)
    assert_equal({ "foo" => "bar" }, request.cookie_jar.to_h)
  end

  def test_fetch_type_error
    assert_raises(KeyError) do
      request.cookie_jar.fetch(:omglolwut)
    end
  end

  def test_each
    request.cookie_jar["foo"] = :bar
    list = []
    request.cookie_jar.each do |k, v|
      list << [k, v]
    end

    assert_equal [["foo", :bar]], list
  end

  def test_enumerable
    request.cookie_jar["foo"] = :bar
    actual = request.cookie_jar.map { |k, v| [k.to_s, v.to_s] }
    assert_equal [["foo", "bar"]], actual
  end

  def test_key_methods
    assert_not request.cookie_jar.key?(:foo)
    assert_not request.cookie_jar.has_key?("foo")

    request.cookie_jar[:foo] = :bar
    assert request.cookie_jar.key?(:foo)
    assert request.cookie_jar.has_key?("foo")
  end

  def test_write_doesnt_set_a_nil_header
    headers = {}
    request.cookie_jar.write(headers)
    assert_not_includes headers, "Set-Cookie"
  end
end

class CookiesMiddlewareTest < ActiveSupport::TestCase
  def test_sets_expected_cookie_header
    request = ActionDispatch::Request.empty
    request.cookie_jar[:foo] = "bar"
    env = Rack::MockRequest.env_for("", request.env)

    _status, headers, _body = Rack::Lint.new(
      ActionDispatch::Cookies.new(
        Rack::Lint.new(lambda { |_env| [ 200, {}, [] ] })
      )
    ).call(env)

    assert_equal "foo=bar; path=/", headers["set-cookie"]
  end
end

class CookiesTest < ActionController::TestCase
  include CookieAssertions

  class CustomSerializer
    def self.load(value)
      value.to_s + " and loaded"
    end

    def self.dump(value)
      value.to_s + " was dumped"
    end
  end

  class TestController < ActionController::Base
    def authenticate
      cookies["user_name"] = "david"
      head :ok
    end

    def authenticate_for_fourteen_days
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10, 5) }
      head :ok
    end

    def authenticate_for_fourteen_days_with_symbols
      cookies[:user_name] = { value: "david", expires: Time.utc(2005, 10, 10, 5) }
      head :ok
    end

    def set_multiple_cookies
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10, 5) }
      cookies["login"]     = "XJ-122"
      head :ok
    end

    def access_frozen_cookies
      cookies["will"] = "work"
      head :ok
    end

    def set_cookie_if_not_present
      cookies["user_name"] = "alice" unless cookies["user_name"].present?
      head :ok
    end

    def logout
      cookies.delete("user_name")
      head :ok
    end

    alias delete_cookie logout

    def delete_cookie_with_path
      cookies.delete("user_name", path: "/beaten")
      head :ok
    end

    def authenticate_with_http_only
      cookies["user_name"] = { value: "david", httponly: true }
      head :ok
    end

    def authenticate_with_secure
      cookies["user_name"] = { value: "david", secure: true }
      head :ok
    end

    def set_permanent_cookie
      cookies.permanent[:user_name] = "Jamie"
      head :ok
    end

    def set_signed_cookie
      cookies.signed[:user_id] = 45
      head :ok
    end

    def get_signed_cookie
      cookies.signed[:user_id]
      head :ok
    end

    def set_encrypted_cookie
      cookies.encrypted[:foo] = "bar"
      head :ok
    end

    class JSONWrapper
      def initialize(obj)
        @obj = obj
      end

      def as_json(options = nil)
        "wrapped: #{@obj.as_json(options)}"
      end
    end

    def set_wrapped_signed_cookie
      cookies.signed[:user_id] = JSONWrapper.new(45)
      head :ok
    end

    def set_wrapped_encrypted_cookie
      cookies.encrypted[:foo] = JSONWrapper.new("bar")
      head :ok
    end

    def get_encrypted_cookie
      cookies.encrypted[:foo]
      head :ok
    end

    def set_invalid_encrypted_cookie
      cookies[:invalid_cookie] = "invalid--9170e00a57cfc27083363b5c75b835e477bd90cf"
      head :ok
    end

    def raise_data_overflow
      cookies.signed[:foo] = "bye!" * 1024
      head :ok
    end

    def tampered_cookies
      cookies[:tampered] = "BAh7BjoIZm9vIghiYXI%3D--123456780"
      cookies.signed[:tampered]
      head :ok
    end

    def set_permanent_signed_cookie
      cookies.permanent.signed[:remember_me] = 100
      head :ok
    end

    def delete_and_set_cookie
      cookies.delete :user_name
      cookies[:user_name] = { value: "david", expires: Time.utc(2005, 10, 10, 5) }
      head :ok
    end

    def set_cookie_with_domain
      cookies[:user_name] = { value: "rizwanreza", domain: :all }
      head :ok
    end

    def set_cookie_with_domain_all_as_string
      cookies[:user_name] = { value: "rizwanreza", domain: "all" }
      head :ok
    end

    def set_cookie_with_domain_proc
      cookies[:user_name] = { value: "braindeaf", domain: proc { ".sub.www.nextangle.com" } }
      head :ok
    end

    def set_cookie_with_domain_proc_with_request
      cookies[:user_name] = { value: "braindeaf", domain: proc { |req| ".sub.#{req.host}" } }
      head :ok
    end

    def delete_cookie_with_domain
      cookies.delete(:user_name, domain: :all)
      head :ok
    end

    def delete_cookie_with_domain_all_as_string
      cookies.delete(:user_name, domain: "all")
      head :ok
    end

    def set_cookie_with_domain_and_tld
      cookies[:user_name] = { value: "rizwanreza", domain: :all, tld_length: 2 }
      head :ok
    end

    def set_cookie_with_domain_and_longer_tld
      cookies[:user_name] = { value: "rizwanreza", domain: :all, tld_length: 4 }
      head :ok
    end

    def delete_cookie_with_domain_and_tld
      cookies.delete(:user_name, domain: :all, tld_length: 2)
      head :ok
    end

    def set_cookie_with_domains
      cookies[:user_name] = { value: "rizwanreza", domain: %w(example1.com example2.com .example3.com) }
      head :ok
    end

    def delete_cookie_with_domains
      cookies.delete(:user_name, domain: %w(example1.com example2.com .example3.com))
      head :ok
    end

    def symbol_key
      cookies[:user_name] = "david"
      head :ok
    end

    def string_key
      cookies["user_name"] = "dhh"
      head :ok
    end

    def symbol_key_mock
      cookies[:user_name] = "david" if cookies[:user_name] == "andrew"
      head :ok
    end

    def string_key_mock
      cookies["user_name"] = "david" if cookies["user_name"] == "andrew"
      head :ok
    end

    def noop
      head :ok
    end

    def encrypted_cookie
      cookies.encrypted["foo"]
    end

    def cookie_expires_in_two_hours
      cookies[:user_name] = { value: "assain", expires: 2.hours }
      head :ok
    end

    def encrypted_discount_and_user_id_cookie
      cookies.encrypted[:user_id] = { value: 50, expires: 1.hour }
      cookies.encrypted[:discount_percentage] = 10

      head :ok
    end

    def signed_discount_and_user_id_cookie
      cookies.signed[:user_id] = { value: 50, expires: 1.hour }
      cookies.signed[:discount_percentage] = 10

      head :ok
    end

    def rails_5_2_stable_encrypted_cookie_with_authenticated_encryption_flag_on
      # cookies.encrypted[:favorite] = { value: "5-2-Stable Chocolate Cookies", expires: 1000.years }
      cookies[:favorite] = "KvH5lIHvX5vPQkLIK63r/NuIMwzWky8M0Zwk8SZ6DwUv8+srf36geR4nWq5KmhsZIYXA8NRdCZYIfxMKJsOFlz77Gf+Fq8vBBCWJTp95rx39A28TCUTJEyMhCNJO5eie7Skef76Qt5Jo/SCnIADAhzyGQkGBopKRcA==--qXZZFWGbCy6N8AGy--WswoH+xHrNh9MzSXDpB2fA=="

      head :ok
    end

    def rails_5_2_stable_encrypted_cookie_with_authenticated_encryption_flag_off
      cookies[:favorite] = "rTG4zs5UufEFAr+ppKwh+MDMymKyAUMOSaWyYa3uUVmD8sMQqyiyQBxgYeAncDHVZIlo4y+kDVSzp66u1/7BNYpnmFe8ES/YT2m8ckNA23jBDmnRZ9CTNfMIRXjFtfxO9YxEOzzhn0ZiA0/zFtr5wkluXtxplOz959Q7MgLOyvTze2h9p8A=--QHOS3rAEGq/HCxXs--xQNra8dk24Idc2qBtpMLpg=="

      head :ok
    end

    def rails_5_2_stable_signed_cookie_with_authenticated_encryption_flag_on
      # cookies.signed[:favorite] = { value: "5-2-Stable Choco Chip Cookie", expires: 1000.years }
      cookies[:favorite] = "eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJaUUxTFRJdFUzUmhZbXhsSUVOb2IyTnZJRU5vYVhBZ1EyOXZhMmxsQmpvR1JWUT0iLCJleHAiOiIzMDE4LTA3LTExVDE2OjExOjI2Ljc1M1oiLCJwdXIiOm51bGx9fQ==--7df5d885b78b70a501d6e82140ae91b24060ac00"

      head :ok
    end

    def rails_5_2_stable_signed_cookie_with_authenticated_encryption_flag_off
      cookies[:favorite] = "BAhJIiE1LTItU3RhYmxlIENob2NvIENoaXAgQ29va2llBjoGRVQ=--50bbdbf8d64f5a3ec3e54878f54d4f55b6cb3aff"

      head :ok
    end

    def set_same_site_strict
      cookies["user_name"] = { value: "david", same_site: :strict }
      head :ok
    end

    def set_same_site_nil
      cookies["user_name"] = { value: "david", same_site: nil }
      head :ok
    end
  end

  tests TestController

  SECRET_KEY_BASE = "b3c631c314c0bbca50c1b2843150fe33"
  SIGNED_COOKIE_SALT = "signed cookie"
  ENCRYPTED_COOKIE_SALT = "encrypted cookie"
  ENCRYPTED_SIGNED_COOKIE_SALT = "signed encrypted cookie"
  AUTHENTICATED_ENCRYPTED_COOKIE_SALT = "authenticated encrypted cookie"

  def setup
    super

    @request.env["action_dispatch.key_generator"] = ActiveSupport::KeyGenerator.new(SECRET_KEY_BASE, iterations: 2)
    @request.env["action_dispatch.cookies_rotations"] = ActiveSupport::Messages::RotationConfiguration.new

    @request.env["action_dispatch.secret_key_base"] = SECRET_KEY_BASE
    @request.env["action_dispatch.use_authenticated_cookie_encryption"] = true

    @request.env["action_dispatch.signed_cookie_salt"] = SIGNED_COOKIE_SALT
    @request.env["action_dispatch.encrypted_cookie_salt"] = ENCRYPTED_COOKIE_SALT
    @request.env["action_dispatch.encrypted_signed_cookie_salt"] = ENCRYPTED_SIGNED_COOKIE_SALT
    @request.env["action_dispatch.authenticated_encrypted_cookie_salt"] = AUTHENTICATED_ENCRYPTED_COOKIE_SALT

    @request.env["action_dispatch.cookies_same_site_protection"] = proc { :lax }
    @request.host = "www.nextangle.com"
  end

  def test_setting_cookie_with_no_same_site_protection
    @request.env["action_dispatch.cookies_same_site_protection"] = proc { :none }

    get :authenticate
    assert_set_cookie_header "user_name=david; path=/; SameSite=None"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_same_site_protection_proc_normal_user_agent
    @request.env["action_dispatch.cookies_same_site_protection"] = Proc.new do |request|
      :strict unless request.user_agent == "spooky browser"
    end

    get :authenticate
    assert_set_cookie_header "user_name=david; path=/; SameSite=Strict"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_same_site_protection_proc_special_user_agent
    @request.env["action_dispatch.cookies_same_site_protection"] = Proc.new do |request|
      :strict unless request.user_agent == "spooky browser"
    end

    request.user_agent = "spooky browser"
    get :authenticate
    assert_set_cookie_header "user_name=david; path=/"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_misspelled_same_site_protection_raises
    @request.env["action_dispatch.cookies_same_site_protection"] = proc { :funky }

    error = assert_raise ArgumentError do
      get :authenticate
    end
    assert_match(/Invalid :?Same_?Site value: :funky/i, error.message)
  end

  def test_setting_cookie_with_same_site_strict
    @request.env["action_dispatch.cookies_same_site_protection"] = proc { :strict }

    get :authenticate
    assert_set_cookie_header "user_name=david; path=/; SameSite=Strict"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_same_site_nil
    @request.env["action_dispatch.cookies_same_site_protection"] = proc { nil }

    get :authenticate
    assert_set_cookie_header "user_name=david; path=/"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_specific_same_site_strict
    @request.env["action_dispatch.cookies_same_site_protection"] = proc { :lax }

    get :set_same_site_strict
    assert_set_cookie_header "user_name=david; path=/; SameSite=Strict"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_specific_same_site_nil
    @request.env["action_dispatch.cookies_same_site_protection"] = proc { :lax }

    get :set_same_site_nil
    assert_set_cookie_header "user_name=david; path=/"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie
    get :authenticate
    assert_set_cookie_header "user_name=david; path=/; SameSite=Lax"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_the_same_value_to_cookie
    request.cookies[:user_name] = "david"
    get :authenticate
    assert_empty response.cookies
  end

  def test_setting_the_same_value_to_permanent_cookie
    request.cookies[:user_name] = "Jamie"
    get :set_permanent_cookie
    assert_equal({ "user_name" => "Jamie" }, response.cookies)
  end

  def test_setting_cookie_for_fourteen_days
    get :authenticate_for_fourteen_days
    assert_set_cookie_header "user_name=david; path=/; expires=Mon, 10 Oct 2005 05:00:00 GMT; SameSite=Lax"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_for_fourteen_days_with_symbols
    get :authenticate_for_fourteen_days_with_symbols
    assert_set_cookie_header "user_name=david; path=/; expires=Mon, 10 Oct 2005 05:00:00 GMT; SameSite=Lax"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_http_only
    get :authenticate_with_http_only
    assert_set_cookie_header "user_name=david; path=/; HttpOnly; SameSite=Lax"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_secure
    @request.env["HTTPS"] = "on"
    get :authenticate_with_secure
    assert_set_cookie_header "user_name=david; path=/; secure; SameSite=Lax"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_secure_on_onion_address
    @request.host = "fake.onion"
    get :authenticate_with_secure
    assert_set_cookie_header "user_name=david; path=/; secure; SameSite=Lax"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_setting_cookie_with_secure_when_always_write_cookie_is_true
    old_cookie, @request.cookie_jar.always_write_cookie = @request.cookie_jar.always_write_cookie, true
    get :authenticate_with_secure
    assert_set_cookie_header "user_name=david; path=/; secure; SameSite=Lax"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  ensure
    @request.cookie_jar.always_write_cookie = old_cookie
  end

  def test_not_setting_cookie_with_secure
    get :authenticate_with_secure
    assert_not_set_cookie_header("user_name")
    assert_not_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_multiple_cookies
    get :set_multiple_cookies
    assert_equal 2, @response.cookies.size
    assert_set_cookie_header ["user_name=david; path=/; expires=Mon, 10 Oct 2005 05:00:00 GMT; SameSite=Lax", "login=XJ-122; path=/; SameSite=Lax"]
    assert_equal({ "login" => "XJ-122", "user_name" => "david" }, @response.cookies)
  end

  def test_setting_test_cookie
    assert_nothing_raised { get :access_frozen_cookies }
  end

  def test_expiring_cookie
    request.cookies[:user_name] = "Joe"
    get :logout
    assert_set_cookie_header "user_name=; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax"
    assert_equal({ "user_name" => nil }, @response.cookies)
  end

  def test_delete_cookie_with_path
    request.cookies[:user_name] = "Joe"
    get :delete_cookie_with_path
    assert_set_cookie_header "user_name=; path=/beaten; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax"
  end

  def test_delete_cookie_return_value
    request.cookies[:user_name] = "Joe"
    return_value = request.cookies.delete(:user_name)
    assert_equal "Joe", return_value
  end

  def test_delete_unexisting_cookie_return_value
    return_value = request.cookies.delete(:no_such_cookie)
    assert_nil return_value
  end

  def test_delete_unexisting_cookie
    request.cookies.clear
    get :delete_cookie
    assert_empty @response.cookies
  end

  def test_deleted_cookie_predicate
    cookies[:user_name] = "Joe"
    cookies.delete("user_name")
    assert cookies.deleted?("user_name")
    assert_equal false, cookies.deleted?("another")
  end

  # Ensure all HTTP methods have their cookies updated
  [:get, :post, :patch, :put, :delete, :head].each do |method|
    define_method("test_deleting_cookie_#{method}") do
      request.cookies[:user_name] = "Joe"
      public_send method, :logout
      assert_nil cookies[:user_name]
    end
  end

  def test_deleted_cookie_predicate_with_mismatching_options
    cookies[:user_name] = "Joe"
    cookies.delete("user_name", path: "/path")
    assert_equal false, cookies.deleted?("user_name", path: "/different")
  end

  def test_cookies_persist_throughout_request
    response = get :authenticate
    assert_match(/user_name=david/, response.headers["Set-Cookie"])
  end

  def test_set_permanent_cookie
    get :set_permanent_cookie
    assert_match(/Jamie/, @response.headers["Set-Cookie"])
    assert_match(%r(#{20.years.from_now.utc.year}), @response.headers["Set-Cookie"])
  end

  def test_read_permanent_cookie
    get :set_permanent_cookie
    assert_equal "Jamie", @controller.send(:cookies).permanent[:user_name]
  end

  def test_signed_cookie_using_default_digest
    get :set_signed_cookie
    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])

    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: Marshal, digest: "SHA1")
    assert_equal verifier.generate(45), cookies[:user_id]
  end

  def test_signed_cookie_using_custom_digest
    @request.env["action_dispatch.signed_cookie_digest"] = "SHA256"

    get :set_signed_cookie
    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])

    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: Marshal, digest: "SHA256")
    assert_equal verifier.generate(45), cookies[:user_id]
  end

  def test_signed_cookie_rotating_secret_and_digest
    secret = "b3c631c314c0bbca50c1b2843150fe33"

    @request.env["action_dispatch.signed_cookie_digest"] = "SHA256"
    @request.env["action_dispatch.cookies_rotations"].rotate :signed, secret, digest: "SHA1"

    old_message = ActiveSupport::MessageVerifier.new(secret, digest: "SHA1", serializer: Marshal).generate(45)
    @request.headers["Cookie"] = "user_id=#{old_message}"

    get :get_signed_cookie
    assert_equal 45, @controller.send(:cookies).signed[:user_id]

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])
    verifier = ActiveSupport::MessageVerifier.new(secret, digest: "SHA256", serializer: Marshal)
    assert_equal 45, verifier.verify(@response.cookies["user_id"])
  end

  def test_tampered_with_signed_cookie
    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])

    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: Marshal, digest: "SHA1")
    message = verifier.generate(45)

    @request.headers["Cookie"] = "user_id=#{Marshal.dump 45}--#{message.split("--").last}"
    get :get_signed_cookie
    assert_nil @controller.send(:cookies).signed[:user_id]
  end

  def test_signed_cookie_using_default_serializer
    get :set_signed_cookie
    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]
  end

  def test_signed_cookie_using_marshal_serializer
    @request.env["action_dispatch.cookies_serializer"] = :marshal
    get :set_signed_cookie
    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]
  end

  def test_signed_cookie_using_json_serializer
    @request.env["action_dispatch.cookies_serializer"] = :json
    get :set_signed_cookie
    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]
  end

  def test_wrapped_signed_cookie_using_json_serializer
    @request.env["action_dispatch.cookies_serializer"] = :json
    get :set_wrapped_signed_cookie
    cookies = @controller.send :cookies
    assert_not_equal "wrapped: 45", cookies[:user_id]
    assert_equal "wrapped: 45", cookies.signed[:user_id]
  end

  def test_signed_cookie_using_message_pack_serializer
    @request.env["action_dispatch.cookies_serializer"] = :message_pack
    get :set_signed_cookie
    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]
  end

  def test_signed_cookie_using_custom_serializer
    @request.env["action_dispatch.cookies_serializer"] = CustomSerializer
    get :set_signed_cookie
    assert_not_equal 45, cookies[:user_id]
    assert_equal "45 was dumped and loaded", cookies.signed[:user_id]
  end

  def test_signed_cookie_using_marshal_serializer_can_read_from_json_dumped_value
    @request.env["action_dispatch.cookies_serializer"] = :marshal

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])

    json_value = ActiveSupport::MessageVerifier.new(secret, serializer: JSON).generate(45)
    @request.headers["Cookie"] = "user_id=#{json_value}"

    get :get_signed_cookie

    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]

    assert_nil @response.cookies["user_id"]
  end

  def test_signed_cookie_using_hybrid_serializer_can_migrate_marshal_dumped_value_to_json
    @request.env["action_dispatch.cookies_serializer"] = :hybrid

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])

    marshal_value = ActiveSupport::MessageVerifier.new(secret, serializer: Marshal).generate(45)
    @request.headers["Cookie"] = "user_id=#{marshal_value}"

    get :get_signed_cookie

    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]

    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    assert_equal 45, verifier.verify(@response.cookies["user_id"])
  end

  def test_signed_cookie_using_hybrid_serializer_can_read_from_json_dumped_value
    @request.env["action_dispatch.cookies_serializer"] = :hybrid

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])

    json_value = ActiveSupport::MessageVerifier.new(secret, serializer: JSON).generate(45)
    @request.headers["Cookie"] = "user_id=#{json_value}"

    get :get_signed_cookie

    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]

    assert_nil @response.cookies["user_id"]
  end

  def test_signed_cookie_using_json_serializer_will_drop_marshal_dumped_value
    @request.env["action_dispatch.cookies_serializer"] = :json

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])

    marshal_value = ActiveSupport::MessageVerifier.new(secret, serializer: Marshal).generate("bar")

    @request.headers["Cookie"] = "foo=#{::Rack::Utils.escape marshal_value}"

    get :get_signed_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_nil cookies.signed[:foo]
    assert_nil @response.cookies["foo"]
  end

  def test_signed_cookie_using_message_pack_serializer_can_migrate_json_dumped_value_to_message_pack
    @request.env["action_dispatch.cookies_serializer"] = :message_pack

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])

    json_value = ActiveSupport::MessageVerifier.new(secret, serializer: JSON).generate(45)
    @request.headers["Cookie"] = "user_id=#{json_value}"

    get :get_signed_cookie

    cookies = @controller.send :cookies
    assert_not_equal 45, cookies[:user_id]
    assert_equal 45, cookies.signed[:user_id]

    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: ActiveSupport::MessagePack)
    assert_equal 45, verifier.verify(@response.cookies["user_id"])
  end

  def test_accessing_nonexistent_signed_cookie_should_not_raise_an_invalid_signature
    get :set_signed_cookie
    assert_nil @controller.send(:cookies).signed[:non_existent_attribute]
  end

  def test_encrypted_cookie_using_default_serializer
    get :set_encrypted_cookie
    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_nil cookies.signed[:foo]
    assert_equal "bar", cookies.encrypted[:foo]
  end

  def test_encrypted_cookie_using_marshal_serializer
    @request.env["action_dispatch.cookies_serializer"] = :marshal
    get :set_encrypted_cookie
    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_nil cookies.signed[:foo]
    assert_equal "bar", cookies.encrypted[:foo]
  end

  def test_encrypted_cookie_using_json_serializer
    @request.env["action_dispatch.cookies_serializer"] = :json
    get :set_encrypted_cookie
    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_nil cookies.signed[:foo]
    assert_equal "bar", cookies.encrypted[:foo]
  end

  def test_wrapped_encrypted_cookie_using_json_serializer
    @request.env["action_dispatch.cookies_serializer"] = :json
    get :set_wrapped_encrypted_cookie
    cookies = @controller.send :cookies
    assert_not_equal "wrapped: bar", cookies[:foo]
    assert_nil cookies.signed[:foo]
    assert_equal "wrapped: bar", cookies.encrypted[:foo]
  end

  def test_encrypted_cookie_using_message_pack_serializer
    @request.env["action_dispatch.cookies_serializer"] = :message_pack
    get :set_encrypted_cookie
    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_nil cookies.signed[:foo]
    assert_equal "bar", cookies.encrypted[:foo]
  end

  def test_encrypted_cookie_using_custom_serializer
    @request.env["action_dispatch.cookies_serializer"] = CustomSerializer
    get :set_encrypted_cookie
    assert_not_equal "bar", cookies.encrypted[:foo]
    assert_equal "bar was dumped and loaded", cookies.encrypted[:foo]
  end

  def test_encrypted_cookie_using_hybrid_serializer_can_migrate_marshal_dumped_value_to_json
    @request.env["action_dispatch.cookies_serializer"] = :hybrid

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.authenticated_encrypted_cookie_salt"], 32)

    encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: Marshal)
    marshal_value = encryptor.encrypt_and_sign("bar")
    @request.headers["Cookie"] = "foo=#{::Rack::Utils.escape marshal_value}"

    get :get_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_equal "bar", cookies.encrypted[:foo]

    json_encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: JSON)
    assert_not_nil @response.cookies["foo"]
    assert_equal "bar", json_encryptor.decrypt_and_verify(@response.cookies["foo"])
  end

  def test_encrypted_cookie_using_hybrid_serializer_can_read_from_json_dumped_value
    @request.env["action_dispatch.cookies_serializer"] = :hybrid

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.authenticated_encrypted_cookie_salt"], 32)

    encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: JSON)
    json_value = encryptor.encrypt_and_sign("bar")
    @request.headers["Cookie"] = "foo=#{::Rack::Utils.escape json_value}"

    get :get_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_equal "bar", cookies.encrypted[:foo]

    assert_nil @response.cookies["foo"]
  end

  def test_encrypted_cookie_using_json_serializer_will_drop_marshal_dumped_value
    @request.env["action_dispatch.cookies_serializer"] = :json

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.authenticated_encrypted_cookie_salt"], 32)

    encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: Marshal)
    marshal_value = encryptor.encrypt_and_sign("bar")
    @request.headers["Cookie"] = "foo=#{::Rack::Utils.escape marshal_value}"

    get :get_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_nil cookies.encrypted[:foo] # #parse rescues JSON::ParserError and returns nil
    assert_nil @response.cookies["foo"]
  end

  def test_encrypted_cookie_using_message_pack_serializer_can_migrate_json_dumped_value_to_message_pack
    @request.env["action_dispatch.cookies_serializer"] = :message_pack

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.authenticated_encrypted_cookie_salt"], 32)

    encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: JSON)
    marshal_value = encryptor.encrypt_and_sign("bar")
    @request.headers["Cookie"] = "foo=#{::Rack::Utils.escape marshal_value}"

    get :get_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_equal "bar", cookies.encrypted[:foo]

    json_encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: ActiveSupport::MessagePack)
    assert_not_nil @response.cookies["foo"]
    assert_equal "bar", json_encryptor.decrypt_and_verify(@response.cookies["foo"])
  end

  def test_accessing_nonexistent_encrypted_cookie_should_not_raise_invalid_message
    get :set_encrypted_cookie
    assert_nil @controller.send(:cookies).encrypted[:non_existent_attribute]
  end

  def test_setting_invalid_encrypted_cookie_should_return_nil_when_accessing_it
    get :set_invalid_encrypted_cookie
    assert_nil @controller.send(:cookies).encrypted[:invalid_cookie]
  end

  def test_permanent_signed_cookie
    get :set_permanent_signed_cookie
    assert_match(%r(#{20.years.from_now.utc.year}), @response.headers["Set-Cookie"])
    assert_equal 100, @controller.send(:cookies).signed[:remember_me]
  end

  def test_delete_and_set_cookie
    request.cookies[:user_name] = "Joe"
    get :delete_and_set_cookie
    assert_set_cookie_header "user_name=david; path=/; expires=Mon, 10 Oct 2005 05:00:00 GMT; SameSite=Lax"
    assert_equal({ "user_name" => "david" }, @response.cookies)
  end

  def test_raise_data_overflow
    error = assert_raise(ActionDispatch::Cookies::CookieOverflow) do
      get :raise_data_overflow
    end
    assert_equal "foo cookie overflowed with size 5522 bytes", error.message
  end

  def test_tampered_cookies
    assert_nothing_raised do
      get :tampered_cookies
      assert_response :success
    end
  end

  def test_cookie_jar_mutated_by_request_persists_on_future_requests
    get :authenticate
    cookie_jar = @request.cookie_jar
    cookie_jar.signed[:user_id] = 123
    assert_equal ["user_name", "user_id"], @request.cookie_jar.instance_variable_get(:@cookies).keys
    get :get_signed_cookie
    assert_equal ["user_name", "user_id"], @request.cookie_jar.instance_variable_get(:@cookies).keys
  end

  def test_legacy_signed_cookie_is_treated_as_nil_by_signed_cookie_jar_if_tampered
    @request.headers["Cookie"] = "user_id=45"
    get :get_signed_cookie

    assert_nil @controller.send(:cookies).signed[:user_id]
    assert_nil @response.cookies["user_id"]
  end

  def test_legacy_signed_cookie_is_treated_as_nil_by_encrypted_cookie_jar_if_tampered
    @request.headers["Cookie"] = "foo=baz"
    get :get_encrypted_cookie

    assert_nil @controller.send(:cookies).encrypted[:foo]
    assert_nil @response.cookies["foo"]
  end

  def test_use_authenticated_cookie_encryption_uses_legacy_hmac_aes_cbc_encryption_when_not_enabled
    @request.env["action_dispatch.use_authenticated_cookie_encryption"] = nil

    key_generator = @request.env["action_dispatch.key_generator"]
    encrypted_cookie_salt = @request.env["action_dispatch.encrypted_cookie_salt"]
    encrypted_signed_cookie_salt = @request.env["action_dispatch.encrypted_signed_cookie_salt"]
    secret = key_generator.generate_key(encrypted_cookie_salt, ActiveSupport::MessageEncryptor.key_len("aes-256-cbc"))
    sign_secret = key_generator.generate_key(encrypted_signed_cookie_salt)
    encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret, cipher: "aes-256-cbc", digest: "SHA1", serializer: Marshal)

    get :set_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_equal "bar", cookies.encrypted[:foo]
    assert_equal "bar", encryptor.decrypt_and_verify(@response.cookies["foo"])
  end

  def test_rotating_signed_cookies_digest
    @request.env["action_dispatch.signed_cookie_digest"] = "SHA256"
    @request.env["action_dispatch.cookies_rotations"].rotate :signed, digest: "SHA1"

    key_generator = @request.env["action_dispatch.key_generator"]

    old_secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])
    old_value = ActiveSupport::MessageVerifier.new(old_secret).generate(45)

    @request.headers["Cookie"] = "user_id=#{old_value}"
    get :get_signed_cookie

    assert_equal 45, @controller.send(:cookies).signed[:user_id]

    secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])
    verifier = ActiveSupport::MessageVerifier.new(secret, digest: "SHA256")
    assert_equal 45, verifier.verify(@response.cookies["user_id"])
  end

  def test_legacy_hmac_aes_cbc_marshal_mode_falls_back_to_authenticated_encrypted_cookie
    @request.env["action_dispatch.use_authenticated_cookie_encryption"] = nil

    key_generator = @request.env["action_dispatch.key_generator"]
    aead_salt = @request.env["action_dispatch.authenticated_encrypted_cookie_salt"]
    aead_secret = key_generator.generate_key(aead_salt, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm"))
    aead_encryptor = ActiveSupport::MessageEncryptor.new(aead_secret, cipher: "aes-256-gcm", serializer: Marshal)
    marshal_value = aead_encryptor.encrypt_and_sign("bar")

    @request.headers["Cookie"] = "foo=#{::Rack::Utils.escape marshal_value}"

    get :get_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_equal "bar", cookies.encrypted[:foo]

    encrypted_cookie_salt = @request.env["action_dispatch.encrypted_cookie_salt"]
    encrypted_signed_cookie_salt = @request.env["action_dispatch.encrypted_signed_cookie_salt"]
    secret = key_generator.generate_key(encrypted_cookie_salt, ActiveSupport::MessageEncryptor.key_len("aes-256-cbc"))
    sign_secret = key_generator.generate_key(encrypted_signed_cookie_salt)
    hmac_cbc_encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret, cipher: "aes-256-cbc", serializer: Marshal)

    assert_equal "bar", hmac_cbc_encryptor.decrypt_and_verify(@response.cookies["foo"])
  end

  def test_legacy_hmac_aes_cbc_json_mode_falls_back_to_authenticated_encrypted_cookie
    @request.env["action_dispatch.use_authenticated_cookie_encryption"] = nil
    @request.env["action_dispatch.cookies_serializer"] = :json

    key_generator = @request.env["action_dispatch.key_generator"]
    aead_salt = @request.env["action_dispatch.authenticated_encrypted_cookie_salt"]
    aead_secret = key_generator.generate_key(aead_salt, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm"))
    aead_encryptor = ActiveSupport::MessageEncryptor.new(aead_secret, cipher: "aes-256-gcm", serializer: JSON)
    marshal_value = aead_encryptor.encrypt_and_sign("bar")

    @request.headers["Cookie"] = "foo=#{::Rack::Utils.escape marshal_value}"

    get :get_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_equal "bar", cookies.encrypted[:foo]

    encrypted_cookie_salt = @request.env["action_dispatch.encrypted_cookie_salt"]
    encrypted_signed_cookie_salt = @request.env["action_dispatch.encrypted_signed_cookie_salt"]
    secret = key_generator.generate_key(encrypted_cookie_salt, ActiveSupport::MessageEncryptor.key_len("aes-256-cbc"))
    sign_secret = key_generator.generate_key(encrypted_signed_cookie_salt)
    hmac_cbc_encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret, cipher: "aes-256-cbc", serializer: JSON)

    assert_equal "bar", hmac_cbc_encryptor.decrypt_and_verify(@response.cookies["foo"])
  end

  def test_legacy_hmac_aes_cbc_encrypted_marshal_cookie_is_upgraded_to_authenticated_encrypted_cookie
    key_generator = @request.env["action_dispatch.key_generator"]
    encrypted_cookie_salt = @request.env["action_dispatch.encrypted_cookie_salt"]
    encrypted_signed_cookie_salt = @request.env["action_dispatch.encrypted_signed_cookie_salt"]
    secret = key_generator.generate_key(encrypted_cookie_salt, ActiveSupport::MessageEncryptor.key_len("aes-256-cbc"))
    sign_secret = key_generator.generate_key(encrypted_signed_cookie_salt)
    marshal_value = ActiveSupport::MessageEncryptor.new(secret, sign_secret, cipher: "aes-256-cbc", serializer: Marshal).encrypt_and_sign("bar")

    @request.headers["Cookie"] = "foo=#{marshal_value}"

    get :get_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_equal "bar", cookies.encrypted[:foo]

    aead_salt = @request.env["action_dispatch.authenticated_encrypted_cookie_salt"]
    aead_secret = key_generator.generate_key(aead_salt, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm"))
    aead_encryptor = ActiveSupport::MessageEncryptor.new(aead_secret, cipher: "aes-256-gcm", serializer: Marshal)

    assert_equal "bar", aead_encryptor.decrypt_and_verify(@response.cookies["foo"])
  end

  def test_legacy_hmac_aes_cbc_encrypted_json_cookie_is_upgraded_to_authenticated_encrypted_cookie
    @request.env["action_dispatch.cookies_serializer"] = :json

    key_generator = @request.env["action_dispatch.key_generator"]
    encrypted_cookie_salt = @request.env["action_dispatch.encrypted_cookie_salt"]
    encrypted_signed_cookie_salt = @request.env["action_dispatch.encrypted_signed_cookie_salt"]
    secret = key_generator.generate_key(encrypted_cookie_salt, ActiveSupport::MessageEncryptor.key_len("aes-256-cbc"))
    sign_secret = key_generator.generate_key(encrypted_signed_cookie_salt)
    marshal_value = ActiveSupport::MessageEncryptor.new(secret, sign_secret, cipher: "aes-256-cbc", serializer: JSON).encrypt_and_sign("bar")

    @request.headers["Cookie"] = "foo=#{marshal_value}"

    get :get_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_equal "bar", cookies.encrypted[:foo]

    aead_salt = @request.env["action_dispatch.authenticated_encrypted_cookie_salt"]
    aead_secret = key_generator.generate_key(aead_salt)[0, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm")]
    aead_encryptor = ActiveSupport::MessageEncryptor.new(aead_secret, cipher: "aes-256-gcm", serializer: JSON)

    assert_equal "bar", aead_encryptor.decrypt_and_verify(@response.cookies["foo"])
  end

  def test_legacy_hmac_aes_cbc_encrypted_cookie_using_64_byte_key_is_upgraded_to_authenticated_encrypted_cookie
    @request.env["action_dispatch.secret_key_base"] = "c3b95688f35581fad38df788add315ff"
    @request.env["action_dispatch.encrypted_cookie_salt"] = "b3c631c314c0bbca50c1b2843150fe33"
    @request.env["action_dispatch.encrypted_signed_cookie_salt"] = "b3c631c314c0bbca50c1b2843150fe33"

    # Cookie generated with 64 bytes secret
    message = ["566d4e75536d686e633246564e6b493062557079626c566d51574d30515430394c53315665564a694e4563786555744f57537454576b396a5a31566a626e52525054303d2d2d34663234333330623130623261306163363562316266323335396164666364613564643134623131"].pack("H*")
    @request.headers["Cookie"] = "foo=#{message}"

    get :get_encrypted_cookie

    cookies = @controller.send :cookies
    assert_not_equal "bar", cookies[:foo]
    assert_equal "bar", cookies.encrypted[:foo]

    salt = @request.env["action_dispatch.authenticated_encrypted_cookie_salt"]
    secret = @request.env["action_dispatch.key_generator"].generate_key(salt, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm"))
    encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: Marshal)

    assert_equal "bar", encryptor.decrypt_and_verify(@response.cookies["foo"])
  end

  def test_encrypted_cookie_rotating_secret
    secret = "b3c631c314c0bbca50c1b2843150fe33"

    @request.env["action_dispatch.encrypted_cookie_cipher"] = "aes-256-gcm"
    @request.env["action_dispatch.cookies_rotations"].rotate :encrypted, secret, digest: "SHA1"

    key_len = ActiveSupport::MessageEncryptor.key_len("aes-256-gcm")

    old_message = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: Marshal).encrypt_and_sign(45)

    @request.headers["Cookie"] = "foo=#{::Rack::Utils.escape old_message}"

    get :get_encrypted_cookie
    assert_equal 45, @controller.send(:cookies).encrypted[:foo]

    key_generator = @request.env["action_dispatch.key_generator"]
    secret = key_generator.generate_key(@request.env["action_dispatch.authenticated_encrypted_cookie_salt"], key_len)
    encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: "aes-256-gcm", serializer: Marshal)
    assert_equal 45, encryptor.decrypt_and_verify(@response.cookies["foo"])
  end

  def test_cookie_with_hash_value_not_modified_by_rotation
    @request.env["action_dispatch.signed_cookie_digest"] = "SHA256"
    @request.env["action_dispatch.cookies_rotations"].rotate :signed, digest: "SHA1"

    key_generator = @request.env["action_dispatch.key_generator"]
    old_secret = key_generator.generate_key(@request.env["action_dispatch.signed_cookie_salt"])
    old_value = ActiveSupport::MessageVerifier.new(old_secret).generate({ bar: "baz" })

    @request.headers["Cookie"] = "foo=#{old_value}"
    get :get_signed_cookie
    assert_equal({ bar: "baz" }, @controller.send(:cookies).signed[:foo])
  end

  def test_cookie_with_all_domain_option
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.com; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_a_non_standard_tld
    @request.host = "two.subdomains.nextangle.local"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.local; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_australian_style_tld
    @request.host = "nextangle.com.au"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.com.au; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_australian_style_tld_and_two_subdomains
    @request.host = "x.nextangle.com.au"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.com.au; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_uk_style_tld
    @request.host = "nextangle.co.uk"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.co.uk; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_two_letter_one_level_tld
    @request.host = "hawth.ca"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=hawth.ca; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_two_letter_one_level_tld_and_subdomain
    @request.host = "x.hawth.ca"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=hawth.ca; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_uk_style_tld_and_two_subdomains
    @request.host = "x.nextangle.co.uk"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.co.uk; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_host_with_port
    @request.host = "nextangle.local:3000"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.local; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_localhost
    @request.host = "localhost"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_ipv4_address
    @request.host = "192.168.1.1"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_ipv6_address
    @request.host = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    get :set_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; path=/; SameSite=Lax"
  end

  def test_deleting_cookie_with_all_domain_option
    request.cookies[:user_name] = "Joe"
    get :delete_cookie_with_domain
    assert_response :success
    assert_set_cookie_header "user_name=; domain=nextangle.com; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_and_tld_length
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.com; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_a_non_standard_tld_and_tld_length
    @request.host = "two.subdomains.nextangle.local"
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.local; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_a_non_standard_2_letter_tld
    @request.host = "admin.lvh.me"
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=lvh.me; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_host_with_port_and_tld_length
    @request.host = "nextangle.local:3000"
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=nextangle.local; path=/; SameSite=Lax"
  end

  def test_cookie_with_all_domain_option_using_longer_tld_length
    @request.host = "x.y.z.t.com"
    get :set_cookie_with_domain_and_longer_tld
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=y.z.t.com; path=/; SameSite=Lax"
  end

  def test_deleting_cookie_with_all_domain_option_and_tld_length
    request.cookies[:user_name] = "Joe"
    get :delete_cookie_with_domain_and_tld
    assert_response :success
    assert_set_cookie_header "user_name=; domain=nextangle.com; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax"
  end

  def test_cookie_with_several_preset_domains_using_one_of_these_domains
    @request.host = "example1.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=example1.com; path=/; SameSite=Lax"
  end

  def test_cookie_with_several_preset_domains_using_subdomain
    @request.host = "subdomain.example1.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=example1.com; path=/; SameSite=Lax"
  end

  def test_cookie_with_several_preset_domains_using_similar_tld
    @request.host = "example1.com.au"
    get :set_cookie_with_domains
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; path=/; SameSite=Lax"
  end

  def test_cookie_with_several_preset_domains_using_similar_domain
    @request.host = "myexample1.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; path=/; SameSite=Lax"
  end

  def test_cookie_with_several_preset_domains_using_other_domain
    @request.host = "other-domain.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; path=/; SameSite=Lax"
  end

  def test_cookie_with_several_preset_domains_using_shared_domain
    @request.host = "example3.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_set_cookie_header "user_name=rizwanreza; domain=.example3.com; path=/; SameSite=Lax"
  end

  def test_cookie_with_domain_proc
    get :set_cookie_with_domain_proc
    assert_response :success
    assert_set_cookie_header "user_name=braindeaf; domain=.sub.www.nextangle.com; path=/; SameSite=Lax"
  end

  def test_cookie_with_domain_proc_with_request
    get :set_cookie_with_domain_proc_with_request
    assert_response :success
    assert_set_cookie_header "user_name=braindeaf; domain=.sub.www.nextangle.com; path=/; SameSite=Lax"
  end

  def test_deleting_cookie_with_several_preset_domains_using_one_of_these_domains
    @request.host = "example2.com"
    request.cookies[:user_name] = "Joe"
    get :delete_cookie_with_domains
    assert_response :success
    assert_set_cookie_header "user_name=; domain=example2.com; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax"
  end

  def test_deleting_cookie_with_several_preset_domains_using_other_domain
    @request.host = "other-domain.com"
    request.cookies[:user_name] = "Joe"
    get :delete_cookie_with_domains
    assert_response :success
    assert_set_cookie_header "user_name=; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax"
  end

  def test_cookies_hash_is_indifferent_access
    get :symbol_key
    assert_equal "david", cookies[:user_name]
    assert_equal "david", cookies["user_name"]
    get :string_key
    assert_equal "dhh", cookies[:user_name]
    assert_equal "dhh", cookies["user_name"]
  end

  def test_setting_request_cookies_is_indifferent_access
    cookies.clear
    cookies[:user_name] = "andrew"
    get :string_key_mock
    assert_equal "david", cookies["user_name"]

    cookies.clear
    cookies["user_name"] = "andrew"
    get :symbol_key_mock
    assert_equal "david", cookies[:user_name]
  end

  def test_cookies_retained_across_requests
    get :symbol_key
    assert_set_cookie_header "user_name=david; path=/; SameSite=Lax"
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_not_includes @response.headers, "Set-Cookie"
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_not_includes @response.headers, "Set-Cookie"
    assert_equal "david", cookies[:user_name]
  end

  def test_cookies_can_be_cleared
    get :symbol_key
    assert_equal "david", cookies[:user_name]

    cookies.clear
    get :noop
    assert_nil cookies[:user_name]

    get :symbol_key
    assert_equal "david", cookies[:user_name]
  end

  def test_can_set_http_cookie_header
    @request.env["HTTP_COOKIE"] = "user_name=david"
    get :noop
    assert_equal "david", cookies["user_name"]
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_equal "david", cookies["user_name"]
    assert_equal "david", cookies[:user_name]

    @request.env["HTTP_COOKIE"] = "user_name=andrew"
    get :noop
    assert_equal "andrew", cookies["user_name"]
    assert_equal "andrew", cookies[:user_name]
  end

  def test_can_set_request_cookies
    @request.cookies["user_name"] = "david"
    get :noop
    assert_equal "david", cookies["user_name"]
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_equal "david", cookies["user_name"]
    assert_equal "david", cookies[:user_name]

    @request.cookies[:user_name] = "andrew"
    get :noop
    assert_equal "andrew", cookies["user_name"]
    assert_equal "andrew", cookies[:user_name]
  end

  def test_cookies_precedence_over_http_cookie
    @request.env["HTTP_COOKIE"] = "user_name=andrew"
    get :authenticate
    assert_equal "david", cookies["user_name"]
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_equal "david", cookies["user_name"]
    assert_equal "david", cookies[:user_name]
  end

  def test_cookies_precedence_over_request_cookies
    @request.cookies["user_name"] = "andrew"
    get :authenticate
    assert_equal "david", cookies["user_name"]
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_equal "david", cookies["user_name"]
    assert_equal "david", cookies[:user_name]
  end

  def test_cookies_are_not_cleared
    cookies.encrypted["foo"] = "bar"
    get :noop
    assert_equal "bar", @controller.encrypted_cookie
  end

  def test_cookie_override
    get :set_cookie_if_not_present
    assert_equal "alice", cookies["user_name"]
    cookies["user_name"] = "bob"
    get :set_cookie_if_not_present
    assert_equal "bob", cookies["user_name"]
  end

  def test_signed_cookie_with_expires_set_relatively
    request.env["action_dispatch.use_cookies_with_metadata"] = true

    cookies.signed[:user_name] = { value: "assain", expires: 2.hours }

    travel 1.hour
    assert_equal "assain", cookies.signed[:user_name]

    travel 2.hours
    assert_nil cookies.signed[:user_name]
  end

  def test_encrypted_cookie_with_expires_set_relatively
    request.env["action_dispatch.use_cookies_with_metadata"] = true

    cookies.encrypted[:user_name] = { value: "assain", expires: 2.hours }

    travel 1.hour
    assert_equal "assain", cookies.encrypted[:user_name]

    travel 2.hours
    assert_nil cookies.encrypted[:user_name]
  end

  def test_vanilla_cookie_with_expires_set_relatively
    travel_to Time.utc(2017, 8, 15) do
      get :cookie_expires_in_two_hours
      assert_set_cookie_header "user_name=assain; path=/; expires=Tue, 15 Aug 2017 02:00:00 GMT; SameSite=Lax"
    end
  end

  def test_signed_cookie_with_false_value_and_metadata
    request.env["action_dispatch.use_cookies_with_metadata"] = true

    cookies.signed[:foo] = false
    assert_equal false, cookies.signed[:foo]
  end

  def test_encrypted_cookie_with_false_value_and_metadata
    request.env["action_dispatch.use_cookies_with_metadata"] = true

    cookies.encrypted[:foo] = false
    assert_equal false, cookies.encrypted[:foo]
  end

  def test_purpose_metadata_for_encrypted_cookies
    get :encrypted_discount_and_user_id_cookie

    cookies[:discount_percentage] = cookies[:user_id]
    assert_equal 50, cookies.encrypted[:discount_percentage]

    request.env["action_dispatch.use_cookies_with_metadata"] = true

    get :encrypted_discount_and_user_id_cookie

    cookies[:discount_percentage] = cookies[:user_id]
    assert_nil cookies.encrypted[:discount_percentage]
  end

  def test_purpose_metadata_for_signed_cookies
    get :signed_discount_and_user_id_cookie

    cookies[:discount_percentage] = cookies[:user_id]
    assert_equal 50, cookies.signed[:discount_percentage]

    request.env["action_dispatch.use_cookies_with_metadata"] = true

    get :signed_discount_and_user_id_cookie

    cookies[:discount_percentage] = cookies[:user_id]
    assert_nil cookies.signed[:discount_percentage]
  end

  def test_switch_off_metadata_for_encrypted_cookies_if_config_is_false
    request.env["action_dispatch.use_cookies_with_metadata"] = false

    get :encrypted_discount_and_user_id_cookie

    travel 2.hours
    assert_nil cookies.signed[:user_id]
  end

  def test_switch_off_metadata_for_signed_cookies_if_config_is_false
    request.env["action_dispatch.use_cookies_with_metadata"] = false

    get :signed_discount_and_user_id_cookie

    travel 2.hours

    assert_nil cookies.signed[:user_id]
  end

  def test_read_rails_5_2_stable_encrypted_cookies_if_config_is_false
    request.env["action_dispatch.use_cookies_with_metadata"] = false

    get :rails_5_2_stable_encrypted_cookie_with_authenticated_encryption_flag_on

    assert_equal "5-2-Stable Chocolate Cookies", cookies.encrypted[:favorite]

    travel 1001.years do
      assert_nil cookies.encrypted[:favorite]
    end

    get :rails_5_2_stable_encrypted_cookie_with_authenticated_encryption_flag_off

    assert_equal "5-2-Stable Chocolate Cookies", cookies.encrypted[:favorite]
  end

  def test_read_rails_5_2_stable_signed_cookies_if_config_is_false
    request.env["action_dispatch.use_cookies_with_metadata"] = false

    get :rails_5_2_stable_signed_cookie_with_authenticated_encryption_flag_on

    assert_equal "5-2-Stable Choco Chip Cookie", cookies.signed[:favorite]

    travel 1001.years do
      assert_nil cookies.signed[:favorite]
    end

    get :rails_5_2_stable_signed_cookie_with_authenticated_encryption_flag_off

    assert_equal "5-2-Stable Choco Chip Cookie", cookies.signed[:favorite]
  end

  def test_read_rails_5_2_stable_encrypted_cookies_if_use_metadata_config_is_true
    request.env["action_dispatch.use_cookies_with_metadata"] = true

    get :rails_5_2_stable_encrypted_cookie_with_authenticated_encryption_flag_on

    assert_equal "5-2-Stable Chocolate Cookies", cookies.encrypted[:favorite]

    travel 1001.years do
      assert_nil cookies.encrypted[:favorite]
    end

    get :rails_5_2_stable_encrypted_cookie_with_authenticated_encryption_flag_off

    assert_equal "5-2-Stable Chocolate Cookies", cookies.encrypted[:favorite]
  end

  def test_read_rails_5_2_stable_signed_cookies_if_use_metadata_config_is_true
    request.env["action_dispatch.use_cookies_with_metadata"] = true

    get :rails_5_2_stable_signed_cookie_with_authenticated_encryption_flag_on

    assert_equal "5-2-Stable Choco Chip Cookie", cookies.signed[:favorite]

    travel 1001.years do
      assert_nil cookies.signed[:favorite]
    end

    get :rails_5_2_stable_signed_cookie_with_authenticated_encryption_flag_off

    assert_equal "5-2-Stable Choco Chip Cookie", cookies.signed[:favorite]
  end
end
