require "#{File.dirname(__FILE__)}/../../abstract_unit"
require 'action_controller/cgi_process'
require 'action_controller/cgi_ext'

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
  def self.default_session_options
    { 'database_manager' => CGI::Session::CookieStore,
      'session_key' => '_myapp_session',
      'secret' => 'Keep it secret; keep it safe.',
      'no_cookies' => true,
      'no_hidden' => true }
  end

  def self.cookies
    { :empty => ['BAgw--0686dcaccc01040f4bd4f35fe160afe9bc04c330', {}],
      :a_one => ['BAh7BiIGYWkG--5689059497d7f122a7119f171aef81dcfd807fec', { 'a' => 1 }],
      :typical => ['BAh7ByIMdXNlcl9pZGkBeyIKZmxhc2h7BiILbm90aWNlIgxIZXkgbm93--9d20154623b9eeea05c62ab819be0e2483238759', { 'user_id' => 123, 'flash' => { 'notice' => 'Hey now' }}],
      :flashed => ['BAh7ByIMdXNlcl9pZGkBeyIKZmxhc2h7AA%3D%3D--bf9785a666d3c4ac09f7fe3353496b437546cfbf', { 'user_id' => 123, 'flash' => {} }] }
  end

  def setup
    ENV.delete('HTTP_COOKIE')
  end

  def test_raises_argument_error_if_missing_session_key
    [nil, ''].each do |blank|
      assert_raise(ArgumentError, blank.inspect) { new_session 'session_key' => blank }
    end
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
    cookies(:empty, :a_one, :typical).each do |value, expected|
      set_cookie! value
      new_session do |session|
        assert_nil session['lazy loads the data hash']
        assert_equal expected, session.dbman.data
      end
    end
  end

  def test_restore_deletes_tampered_cookies
    set_cookie! 'a--b'
    new_session do |session|
      assert_raise(CGI::Session::CookieStore::TamperedWithCookie) { session['fail'] }
      assert_cookie_deleted session
    end
  end

  def test_close_doesnt_write_cookie_if_data_is_blank
    new_session do |session|
      assert_no_cookies session
      session.close
      assert_no_cookies session
    end
  end

  def test_close_doesnt_write_cookie_if_data_is_unchanged
    set_cookie! cookie_value(:typical)
    new_session do |session|
      assert_no_cookies session
      session['user_id'] = session['user_id']
      session.close
      assert_no_cookies session
    end
  end

  def test_close_raises_when_data_overflows
    set_cookie! cookie_value(:empty)
    new_session do |session|
      session['overflow'] = 'bye!' * 1024
      assert_raise(CGI::Session::CookieStore::CookieOverflow) { session.close }
      assert_no_cookies session
    end
  end

  def test_close_marshals_and_writes_cookie
    set_cookie! cookie_value(:typical)
    new_session do |session|
      assert_no_cookies session
      session['flash'] = {}
      assert_no_cookies session
      session.close
      assert_equal 1, session.cgi.output_cookies.size
      cookie = session.cgi.output_cookies.first
      assert_cookie cookie, cookie_value(:flashed)
    end
  end

  def test_delete_writes_expired_empty_cookie_and_sets_data_to_nil
    set_cookie! cookie_value(:typical)
    new_session do |session|
      assert_no_cookies session
      session.delete
      assert_cookie_deleted session

      # @data is set to nil so #close doesn't send another cookie.
      session.close
      assert_cookie_deleted session
    end
  end

  def test_new_session_doesnt_reuse_deleted_cookie_data
    set_cookie! cookie_value(:typical)

    new_session do |session|
      assert_not_nil session['user_id']
      session.delete

      # Start a new session using the same CGI instance.
      post_delete_session = CGI::Session.new(session.cgi, self.class.default_session_options)
      assert_nil post_delete_session['user_id']
    end
  end

  private
    def assert_no_cookies(session)
      assert_nil session.cgi.output_cookies, session.cgi.output_cookies.inspect
    end

    def assert_cookie_deleted(session, message = 'Expected session deletion cookie to be set')
      assert_equal 1, session.cgi.output_cookies.size
      cookie = session.cgi.output_cookies.first
      assert_cookie cookie, nil, 1.year.ago.to_date, message
    end

    def assert_cookie(cookie, value = nil, expires = nil, message = nil)
      assert_equal '_myapp_session', cookie.name, message
      assert_equal [value].compact, cookie.value, message
      assert_equal expires, cookie.expires ? cookie.expires.to_date : cookie.expires, message
    end


    def cookies(*which)
      self.class.cookies.values_at(*which)
    end

    def cookie_value(which)
      self.class.cookies[which].first
    end

    def set_cookie!(value)
      ENV['HTTP_COOKIE'] = "_myapp_session=#{value}"
    end

    def new_session(options = {})
      with_cgi do |cgi|
        assert_nil cgi.output_hidden, "Output hidden params should be empty: #{cgi.output_hidden.inspect}"
        assert_nil cgi.output_cookies, "Output cookies should be empty: #{cgi.output_cookies.inspect}"

        @options = self.class.default_session_options.merge(options)
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

      cgi = CGI.new('query', StringIO.new(''))
      yield cgi if block_given?
      cgi
    end
end


class CookieStoreWithBlockAsSecretTest < CookieStoreTest
  def self.default_session_options
    CookieStoreTest.default_session_options.merge 'secret' => Proc.new { 'Keep it secret; keep it safe.' }
  end
end


class CookieStoreWithMD5DigestTest < CookieStoreTest
  def self.default_session_options
    CookieStoreTest.default_session_options.merge 'digest' => 'MD5'
  end

  def self.cookies
    { :empty => ['BAgw--0415cc0be9579b14afc22ee2d341aa21', {}],
      :a_one => ['BAh7BiIGYWkG--5a0ed962089cc6600ff44168a5d59bc8', { 'a' => 1 }],
      :typical => ['BAh7ByIMdXNlcl9pZGkBeyIKZmxhc2h7BiILbm90aWNlIgxIZXkgbm93--f426763f6ef435b3738b493600db8d64', { 'user_id' => 123, 'flash' => { 'notice' => 'Hey now' }}],
      :flashed => ['BAh7ByIMdXNlcl9pZGkBeyIKZmxhc2h7AA%3D%3D--0af9156650dab044a53a91a4ddec2c51', { 'user_id' => 123, 'flash' => {} }] }
  end
end
