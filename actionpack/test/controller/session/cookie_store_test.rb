require "#{File.dirname(__FILE__)}/../../abstract_unit"
require 'action_controller/cgi_process'
require 'action_controller/cgi_ext/cgi_ext'

require 'stringio'

# Expose for tests.
class CGI
  attr_reader :output_cookies, :output_hidden

  class Session
    attr_reader :dbman

    class CookieStore
      attr_reader :data, :original, :cookie_options
    end
  end
end

class CookieStoreTest < Test::Unit::TestCase
  DefaultSessionOptions = {
    'database_manager' => CGI::Session::CookieStore,
    'session_key' => '_myapp_session',
    'secret' => 'Keep it secret; keep it safe.',
    'no_cookies' => true,
    'no_hidden' => true
  }

  module Cookies
    EMPTY = ['BAh7AA%3D%3D--fda6e506d1cc14a1d8e97fd3f5abf77e756ff2d987b069e5f9b0fbadb62ca6fb3cf523e8dfc61464dd98d7bd2d675e0713ce54226f428e521b4c5d21d2389eae', {}]
    A_ONE = ['BAh7BiIGYWkG--8dfd099b297a60f6742933b1217b81e91c50237eedd8b25f3ce47b86394e14de3b17128225ba984e7d8660f7777e33979b8d98091dc87400be8c54ebbfdbe599', { 'a' => 1 }]
    TYPICAL = ['BAh7ByIMdXNlcl9pZGkBeyIKZmxhc2h7BiILbm90aWNlIgxIZXkgbm93--251fa4706464e87bcb90c76a27a1dee2410ff81a1ba9903f9760263ad44e739a42d0a5d5d7229087ddb4b3e1d6b956a6c4f6a2f8dcb5a5b281a342fed12d38c0', { 'user_id' => 123, 'flash' => { 'notice' => 'Hey now' }}]
    FLASHED = ['BAh7ByIMdXNlcl9pZGkBeyIKZmxhc2h7AA%3D%3D--a574ffd23d744c363f94a75b449d02dd619fd9409978ea0a2797c98dc638bff9fe0f9cacb2106b1610f0731b386416bcca6e11e031b7885719ba8c956dfd6f2c', { 'user_id' => 123, 'flash' => {} }]
  end

  def setup
    ENV.delete('HTTP_COOKIE')
  end

  def test_raises_argument_error_if_missing_secret
    [nil, ''].each do |blank|
      assert_raise(ArgumentError, blank.inspect) { new_session 'secret' => blank }
    end
  end

  def test_reconfigures_session_to_omit_id_cookie_and_hidden_field
    new_session do |session|
      assert_equal true, @options['no_hidden']
      assert_equal true, @options['no_cookies']
    end
  end

  def test_restore_unmarshals_missing_cookie_as_empty_hash
    new_session do |session|
      assert_nil session.dbman.data
      assert_nil session['test']
      assert_equal Hash.new, session.dbman.data
    end
  end

  def test_restore_unmarshals_good_cookies
    [Cookies::EMPTY, Cookies::A_ONE, Cookies::TYPICAL].each do |value, expected|
      set_cookie! value
      new_session do |session|
        assert_nil session['lazy loads the data hash']
        assert_equal expected, session.dbman.data
      end
    end
  end

  def test_close_doesnt_write_cookie_if_data_is_unchanged
    set_cookie! Cookies::TYPICAL.first
    new_session do |session|
      assert_nil session.cgi.output_cookies, session.cgi.output_cookies.inspect
      session['user_id'] = session['user_id']
      assert_nil session.cgi.output_cookies, session.cgi.output_cookies.inspect
    end
  end

  def test_close_marshals_and_writes_cookie
    set_cookie! Cookies::TYPICAL.first
    new_session do |session|
      assert_nil session.cgi.output_cookies, session.cgi.output_cookies.inspect
      session['flash'] = {}
      assert_nil session.cgi.output_cookies, session.cgi.output_cookies.inspect
      session.close
      assert_equal 1, session.cgi.output_cookies.size
      cookie = session.cgi.output_cookies.first
      assert_equal ['_myapp_session', [Cookies::FLASHED.first]],
                   [cookie.name, cookie.value]
    end
  end

  def test_delete_writes_expired_empty_cookie
    set_cookie! Cookies::TYPICAL.first
    new_session do |session|
      assert_nil session.cgi.output_cookies, session.cgi.output_cookies.inspect
      session.delete
      assert_equal 1, session.cgi.output_cookies.size
      cookie = session.cgi.output_cookies.first
      assert_equal ['_myapp_session', [], 1.year.ago.to_date],
                   [cookie.name, cookie.value, cookie.expires.to_date]
    end
  end

  private
    def set_cookie!(value)
      ENV['HTTP_COOKIE'] = "_myapp_session=#{value}"
    end

    def new_session(options = {})
      with_cgi do |cgi|
        assert_nil cgi.output_hidden, "Output hidden params should be empty: #{cgi.output_hidden.inspect}"
        assert_nil cgi.output_cookies, "Output cookies should be empty: #{cgi.output_cookies.inspect}"

        @options = DefaultSessionOptions.merge(options)
        session = CGI::Session.new(cgi, @options)

        assert_nil cgi.output_hidden, "Output hidden params should be empty: #{cgi.output_hidden.inspect}"
        assert_nil cgi.output_cookies, "Output cookies should be empty: #{cgi.output_cookies.inspect}"

        yield session if block_given?
        session
      end
    end

    def with_cgi
      ENV['REQUEST_METHOD'] = 'GET'
      ENV['HTTP_HOST'] = 'example.com'
      ENV['QUERY_STRING'] = ''

      $stdin, old_stdin = StringIO.new(''), $stdin
      yield CGI.new
    ensure
      $stdin = old_stdin
    end
end
