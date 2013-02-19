require 'abstract_unit'
# FIXME remove DummyKeyGenerator and this require in 4.1
require 'active_support/key_generator'

class CookiesTest < ActionController::TestCase
  class TestController < ActionController::Base
    def authenticate
      cookies["user_name"] = "david"
      head :ok
    end

    def set_with_with_escapable_characters
      cookies["that & guy"] = "foo & bar => baz"
      head :ok
    end

    def authenticate_for_fourteen_days
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10,5) }
      head :ok
    end

    def authenticate_for_fourteen_days_with_symbols
      cookies[:user_name] = { :value => "david", :expires => Time.utc(2005, 10, 10,5) }
      head :ok
    end

    def set_multiple_cookies
      cookies["user_name"] = { "value" => "david", "expires" => Time.utc(2005, 10, 10,5) }
      cookies["login"]     = "XJ-122"
      head :ok
    end

    def access_frozen_cookies
      cookies["will"] = "work"
      head :ok
    end

    def logout
      cookies.delete("user_name")
      head :ok
    end

    alias delete_cookie logout

    def delete_cookie_with_path
      cookies.delete("user_name", :path => '/beaten')
      head :ok
    end

    def authenticate_with_http_only
      cookies["user_name"] = { :value => "david", :httponly => true }
      head :ok
    end

    def authenticate_with_secure
      cookies["user_name"] = { :value => "david", :secure => true }
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

    def set_encrypted_cookie
      cookies.encrypted[:foo] = 'bar'
      head :ok
    end

    def set_invalid_encrypted_cookie
      cookies[:invalid_cookie] = 'invalid--9170e00a57cfc27083363b5c75b835e477bd90cf'
      head :ok
    end

    def raise_data_overflow
      cookies.signed[:foo] = 'bye!' * 1024
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
      cookies[:user_name] = { :value => "david", :expires => Time.utc(2005, 10, 10,5) }
      head :ok
    end

    def set_cookie_with_domain
      cookies[:user_name] = {:value => "rizwanreza", :domain => :all}
      head :ok
    end

    def delete_cookie_with_domain
      cookies.delete(:user_name, :domain => :all)
      head :ok
    end

    def set_cookie_with_domain_and_tld
      cookies[:user_name] = {:value => "rizwanreza", :domain => :all, :tld_length => 2}
      head :ok
    end

    def delete_cookie_with_domain_and_tld
      cookies.delete(:user_name, :domain => :all, :tld_length => 2)
      head :ok
    end

    def set_cookie_with_domains
      cookies[:user_name] = {:value => "rizwanreza", :domain => %w(example1.com example2.com .example3.com)}
      head :ok
    end

    def delete_cookie_with_domains
      cookies.delete(:user_name, :domain => %w(example1.com example2.com .example3.com))
      head :ok
    end

    def symbol_key
      cookies[:user_name] = "david"
      head :ok
    end

    def string_key
      cookies['user_name'] = "dhh"
      head :ok
    end

    def symbol_key_mock
      cookies[:user_name] = "david" if cookies[:user_name] == "andrew"
      head :ok
    end

    def string_key_mock
      cookies['user_name'] = "david" if cookies['user_name'] == "andrew"
      head :ok
    end

    def noop
      head :ok
    end
  end

  tests TestController

  def setup
    super
    @request.env["action_dispatch.key_generator"] = ActiveSupport::KeyGenerator.new("b3c631c314c0bbca50c1b2843150fe33")
    @request.env["action_dispatch.signed_cookie_salt"] = "b3c631c314c0bbca50c1b2843150fe33"
    @request.env["action_dispatch.encrypted_cookie_salt"] = "b3c631c314c0bbca50c1b2843150fe33"
    @request.env["action_dispatch.encrypted_signed_cookie_salt"] = "b3c631c314c0bbca50c1b2843150fe33"
    @request.host = "www.nextangle.com"
  end

  def test_fetch
    x = Object.new
    assert_not request.cookie_jar.key?('zzzzzz')
    assert_equal x, request.cookie_jar.fetch('zzzzzz', x)
    assert_not request.cookie_jar.key?('zzzzzz')
  end

  def test_fetch_exists
    x = Object.new
    request.cookie_jar['foo'] = 'bar'
    assert_equal 'bar', request.cookie_jar.fetch('foo', x)
  end

  def test_fetch_block
    x = Object.new
    assert_not request.cookie_jar.key?('zzzzzz')
    assert_equal x, request.cookie_jar.fetch('zzzzzz') { x }
  end

  def test_key_is_to_s
    request.cookie_jar['foo'] = 'bar'
    assert_equal 'bar', request.cookie_jar.fetch(:foo)
  end

  def test_fetch_type_error
    assert_raises(KeyError) do
      request.cookie_jar.fetch(:omglolwut)
    end
  end

  def test_each
    request.cookie_jar['foo'] = :bar
    list = []
    request.cookie_jar.each do |k,v|
      list << [k, v]
    end

    assert_equal [['foo', :bar]], list
  end

  def test_enumerable
    request.cookie_jar['foo'] = :bar
    actual = request.cookie_jar.map { |k,v| [k.to_s, v.to_s] }
    assert_equal [['foo', 'bar']], actual
  end

  def test_key_methods
    assert !request.cookie_jar.key?(:foo)
    assert !request.cookie_jar.has_key?("foo")

    request.cookie_jar[:foo] = :bar
    assert request.cookie_jar.key?(:foo)
    assert request.cookie_jar.has_key?("foo")
  end

  def test_setting_cookie
    get :authenticate
    assert_cookie_header "user_name=david; path=/"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_the_same_value_to_cookie
    request.cookies[:user_name] = 'david'
    get :authenticate
    assert response.cookies.empty?
  end

  def test_setting_the_same_value_to_permanent_cookie
    request.cookies[:user_name] = 'Jamie'
    get :set_permanent_cookie
    assert_equal response.cookies, 'user_name' => 'Jamie'
  end

  def test_setting_with_escapable_characters
    get :set_with_with_escapable_characters
    assert_cookie_header "that+%26+guy=foo+%26+bar+%3D%3E+baz; path=/"
    assert_equal({"that & guy" => "foo & bar => baz"}, @response.cookies)
  end

  def test_setting_cookie_for_fourteen_days
    get :authenticate_for_fourteen_days
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10 Oct 2005 05:00:00 -0000"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_for_fourteen_days_with_symbols
    get :authenticate_for_fourteen_days_with_symbols
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10 Oct 2005 05:00:00 -0000"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_with_http_only
    get :authenticate_with_http_only
    assert_cookie_header "user_name=david; path=/; HttpOnly"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_with_secure
    @request.env["HTTPS"] = "on"
    get :authenticate_with_secure
    assert_cookie_header "user_name=david; path=/; secure"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_setting_cookie_with_secure_when_always_write_cookie_is_true
    ActionDispatch::Cookies::CookieJar.any_instance.stubs(:always_write_cookie).returns(true)
    get :authenticate_with_secure
    assert_cookie_header "user_name=david; path=/; secure"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_not_setting_cookie_with_secure
    get :authenticate_with_secure
    assert_not_cookie_header "user_name=david; path=/; secure"
    assert_not_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_multiple_cookies
    get :set_multiple_cookies
    assert_equal 2, @response.cookies.size
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10 Oct 2005 05:00:00 -0000\nlogin=XJ-122; path=/"
    assert_equal({"login" => "XJ-122", "user_name" => "david"}, @response.cookies)
  end

  def test_setting_test_cookie
    assert_nothing_raised { get :access_frozen_cookies }
  end

  def test_expiring_cookie
    request.cookies[:user_name] = 'Joe'
    get :logout
    assert_cookie_header "user_name=; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 -0000"
    assert_equal({"user_name" => nil}, @response.cookies)
  end

  def test_delete_cookie_with_path
    request.cookies[:user_name] = 'Joe'
    get :delete_cookie_with_path
    assert_cookie_header "user_name=; path=/beaten; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 -0000"
  end

  def test_delete_unexisting_cookie
    request.cookies.clear
    get :delete_cookie
    assert @response.cookies.empty?
  end

  def test_deleted_cookie_predicate
    cookies[:user_name] = 'Joe'
    cookies.delete("user_name")
    assert cookies.deleted?("user_name")
    assert_equal false, cookies.deleted?("another")
  end

  def test_deleted_cookie_predicate_with_mismatching_options
    cookies[:user_name] = 'Joe'
    cookies.delete("user_name", :path => "/path")
    assert_equal false, cookies.deleted?("user_name", :path => "/different")
  end

  def test_cookies_persist_throughout_request
    response = get :authenticate
    assert response.headers["Set-Cookie"] =~ /user_name=david/
  end

  def test_permanent_cookie
    get :set_permanent_cookie
    assert_match(/Jamie/, @response.headers["Set-Cookie"])
    assert_match(%r(#{20.years.from_now.utc.year}), @response.headers["Set-Cookie"])
  end

  def test_signed_cookie
    get :set_signed_cookie
    assert_equal 45, @controller.send(:cookies).signed[:user_id]
  end

  def test_accessing_nonexistant_signed_cookie_should_not_raise_an_invalid_signature
    get :set_signed_cookie
    assert_nil @controller.send(:cookies).signed[:non_existant_attribute]
  end

  def test_encrypted_cookie
    get :set_encrypted_cookie
    cookies = @controller.send :cookies
    assert_not_equal 'bar', cookies[:foo]
    assert_raises TypeError do
      cookies.signed[:foo]
    end
    assert_equal 'bar', cookies.encrypted[:foo]
  end

  def test_accessing_nonexistant_encrypted_cookie_should_not_raise_invalid_message
    get :set_encrypted_cookie
    assert_nil @controller.send(:cookies).encrypted[:non_existant_attribute]
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
    request.cookies[:user_name] = 'Joe'
    get :delete_and_set_cookie
    assert_cookie_header "user_name=david; path=/; expires=Mon, 10 Oct 2005 05:00:00 -0000"
    assert_equal({"user_name" => "david"}, @response.cookies)
  end

  def test_raise_data_overflow
    assert_raise(ActionDispatch::Cookies::CookieOverflow) do
      get :raise_data_overflow
    end
  end

  def test_tampered_cookies
    assert_nothing_raised do
      get :tampered_cookies
      assert_response :success
    end
  end

  def test_raises_argument_error_if_missing_secret
    assert_raise(ArgumentError, nil.inspect) {
      @request.env["action_dispatch.key_generator"] = ActiveSupport::DummyKeyGenerator.new(nil)
      get :set_signed_cookie
    }

    assert_raise(ArgumentError, ''.inspect) {
      @request.env["action_dispatch.key_generator"] = ActiveSupport::DummyKeyGenerator.new("")
      get :set_signed_cookie
    }
  end

  def test_raises_argument_error_if_secret_is_probably_insecure
    assert_raise(ArgumentError, "password".inspect) {
      @request.env["action_dispatch.key_generator"] = ActiveSupport::DummyKeyGenerator.new("password")
      get :set_signed_cookie
    }

    assert_raise(ArgumentError, "secret".inspect) {
      @request.env["action_dispatch.key_generator"] = ActiveSupport::DummyKeyGenerator.new("secret")
      get :set_signed_cookie
    }

    assert_raise(ArgumentError, "12345678901234567890123456789".inspect) {
      @request.env["action_dispatch.key_generator"] = ActiveSupport::DummyKeyGenerator.new("12345678901234567890123456789")
      get :set_signed_cookie
    }
  end

  def test_cookie_with_all_domain_option
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.com; path=/"
  end

  def test_cookie_with_all_domain_option_using_a_non_standard_tld
    @request.host = "two.subdomains.nextangle.local"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.local; path=/"
  end

  def test_cookie_with_all_domain_option_using_australian_style_tld
    @request.host = "nextangle.com.au"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.com.au; path=/"
  end

  def test_cookie_with_all_domain_option_using_uk_style_tld
    @request.host = "nextangle.co.uk"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.co.uk; path=/"
  end

  def test_cookie_with_all_domain_option_using_host_with_port
    @request.host = "nextangle.local:3000"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.local; path=/"
  end

  def test_cookie_with_all_domain_option_using_localhost
    @request.host = "localhost"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; path=/"
  end

  def test_cookie_with_all_domain_option_using_ipv4_address
    @request.host = "192.168.1.1"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; path=/"
  end

  def test_cookie_with_all_domain_option_using_ipv6_address
    @request.host = "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    get :set_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; path=/"
  end

  def test_deleting_cookie_with_all_domain_option
    request.cookies[:user_name] = 'Joe'
    get :delete_cookie_with_domain
    assert_response :success
    assert_cookie_header "user_name=; domain=.nextangle.com; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 -0000"
  end

  def test_cookie_with_all_domain_option_and_tld_length
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.com; path=/"
  end

  def test_cookie_with_all_domain_option_using_a_non_standard_tld_and_tld_length
    @request.host = "two.subdomains.nextangle.local"
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.local; path=/"
  end

  def test_cookie_with_all_domain_option_using_host_with_port_and_tld_length
    @request.host = "nextangle.local:3000"
    get :set_cookie_with_domain_and_tld
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.nextangle.local; path=/"
  end

  def test_deleting_cookie_with_all_domain_option_and_tld_length
    request.cookies[:user_name] = 'Joe'
    get :delete_cookie_with_domain_and_tld
    assert_response :success
    assert_cookie_header "user_name=; domain=.nextangle.com; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 -0000"
  end

  def test_cookie_with_several_preset_domains_using_one_of_these_domains
    @request.host = "example1.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=example1.com; path=/"
  end

  def test_cookie_with_several_preset_domains_using_other_domain
    @request.host = "other-domain.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; path=/"
  end

  def test_cookie_with_several_preset_domains_using_shared_domain
    @request.host = "example3.com"
    get :set_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=rizwanreza; domain=.example3.com; path=/"
  end

  def test_deletings_cookie_with_several_preset_domains_using_one_of_these_domains
    @request.host = "example2.com"
    request.cookies[:user_name] = 'Joe'
    get :delete_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=; domain=example2.com; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 -0000"
  end

  def test_deletings_cookie_with_several_preset_domains_using_other_domain
    @request.host = "other-domain.com"
    request.cookies[:user_name] = 'Joe'
    get :delete_cookie_with_domains
    assert_response :success
    assert_cookie_header "user_name=; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 -0000"
  end

  def test_cookies_hash_is_indifferent_access
    get :symbol_key
    assert_equal "david", cookies[:user_name]
    assert_equal "david", cookies['user_name']
    get :string_key
    assert_equal "dhh", cookies[:user_name]
    assert_equal "dhh", cookies['user_name']
  end



  def test_setting_request_cookies_is_indifferent_access
    cookies.clear
    cookies[:user_name] = "andrew"
    get :string_key_mock
    assert_equal "david", cookies['user_name']

    cookies.clear
    cookies['user_name'] = "andrew"
    get :symbol_key_mock
    assert_equal "david", cookies[:user_name]
  end

  def test_cookies_retained_across_requests
    get :symbol_key
    assert_cookie_header "user_name=david; path=/"
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_nil @response.headers["Set-Cookie"]
    assert_equal "david", cookies[:user_name]

    get :noop
    assert_nil @response.headers["Set-Cookie"]
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
    @request.env['HTTP_COOKIE'] = 'user_name=david'
    get :noop
    assert_equal 'david', cookies['user_name']
    assert_equal 'david', cookies[:user_name]

    get :noop
    assert_equal 'david', cookies['user_name']
    assert_equal 'david', cookies[:user_name]

    @request.env['HTTP_COOKIE'] = 'user_name=andrew'
    get :noop
    assert_equal 'andrew', cookies['user_name']
    assert_equal 'andrew', cookies[:user_name]
  end

  def test_can_set_request_cookies
    @request.cookies['user_name'] = 'david'
    get :noop
    assert_equal 'david', cookies['user_name']
    assert_equal 'david', cookies[:user_name]

    get :noop
    assert_equal 'david', cookies['user_name']
    assert_equal 'david', cookies[:user_name]

    @request.cookies[:user_name] = 'andrew'
    get :noop
    assert_equal 'andrew', cookies['user_name']
    assert_equal 'andrew', cookies[:user_name]
  end

  def test_cookies_precedence_over_http_cookie
    @request.env['HTTP_COOKIE'] = 'user_name=andrew'
    get :authenticate
    assert_equal 'david', cookies['user_name']
    assert_equal 'david', cookies[:user_name]

    get :noop
    assert_equal 'david', cookies['user_name']
    assert_equal 'david', cookies[:user_name]
  end

  def test_cookies_precedence_over_request_cookies
    @request.cookies['user_name'] = 'andrew'
    get :authenticate
    assert_equal 'david', cookies['user_name']
    assert_equal 'david', cookies[:user_name]

    get :noop
    assert_equal 'david', cookies['user_name']
    assert_equal 'david', cookies[:user_name]
  end

  private
    def assert_cookie_header(expected)
      header = @response.headers["Set-Cookie"]
      if header.respond_to?(:to_str)
        assert_equal expected.split("\n").sort, header.split("\n").sort
      else
        assert_equal expected.split("\n"), header
      end
    end

    def assert_not_cookie_header(expected)
      header = @response.headers["Set-Cookie"]
      if header.respond_to?(:to_str)
        assert_not_equal expected.split("\n").sort, header.split("\n").sort
      else
        assert_not_equal expected.split("\n"), header
      end
    end
end
