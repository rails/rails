require "#{File.dirname(__FILE__)}/../../abstract_unit"
require 'action_controller/cgi_process'
require 'action_controller/cgi_ext'


class CGI::Session
  def cache
    dbman.instance_variable_get(:@cache)
  end
end


uses_mocha 'MemCacheStore tests' do
if defined? MemCache::MemCacheError

class MemCacheStoreTest < Test::Unit::TestCase
  SESSION_KEY_RE = /^session:[0-9a-z]+/
  CONN_TEST_KEY = 'connection_test'
  MULTI_TEST_KEY = '0123456789'
  TEST_DATA = 'Hello test'

  def self.get_mem_cache_if_available
    begin
      require 'memcache'
      cache = MemCache.new('127.0.0.1')
      # Test availability of the connection
      cache.set(CONN_TEST_KEY, 1)
      unless cache.get(CONN_TEST_KEY) == 1
        puts 'Warning: memcache server available but corrupted.'
        return nil
      end
    rescue LoadError, MemCache::MemCacheError
      return nil
    end
    return cache
  end

  CACHE = get_mem_cache_if_available


  def test_initialization
    assert_raise(ArgumentError) { new_session('session_id' => '!invalid_id') }
    new_session do |s|
      assert_equal Hash.new, s.cache.get('session:' + s.session_id)
    end
  end


  def test_storage
    d = rand(0xffff)
    new_session do |s|
      session_key = 'session:' + s.session_id
      unless CACHE
        s.cache.expects(:get).with(session_key) \
                             .returns(:test => d)
        s.cache.expects(:set).with(session_key,
                                   has_entry(:test, d),
                                   0)
      end
      s[:test] = d
      s.close
      assert_equal d, s.cache.get(session_key)[:test]
      assert_equal d, s[:test]
    end
  end


  def test_deletion
    new_session do |s|
      session_key = 'session:' + s.session_id
      unless CACHE
        s.cache.expects(:delete)
        s.cache.expects(:get).with(session_key) \
                             .returns(nil)
      end
      s[:test] = rand(0xffff)
      s.delete
      assert_nil s.cache.get(session_key)
    end
  end


  def test_other_session_retrieval
    new_session do |sa|
      unless CACHE
        sa.cache.expects(:set).with('session:' + sa.session_id,
                                    has_entry(:test, TEST_DATA),
                                    0)
      end
      sa[:test] = TEST_DATA
      sa.close
      new_session('session_id' => sa.session_id) do |sb|
        unless CACHE
          sb.cache.expects(:[]).with('session:' + sb.session_id) \
                               .returns(:test => TEST_DATA)
        end
        assert_equal(TEST_DATA, sb[:test])
      end
    end
  end


  def test_multiple_sessions
    s_slots = Array.new(10)
    operation = :write
    last_data = nil
    reads = writes = 0
    50.times do
      current = rand(10)
      s_slots[current] ||= new_session('session_id' => MULTI_TEST_KEY,
                                       'new_session' => true)
      s = s_slots[current]
      case operation
      when :write
        last_data = rand(0xffff)
        unless CACHE
          s.cache.expects(:set).with('session:' + MULTI_TEST_KEY,
                                     { :test => last_data },
                                     0)
        end
        s[:test] = last_data
        s.close
        writes += 1
      when :read
        # Make CGI::Session#[] think there was no data retrieval yet.
        # Normally, the session caches the data during its lifetime.
        s.instance_variable_set(:@data, nil)
        unless CACHE
          s.cache.expects(:[]).with('session:' + MULTI_TEST_KEY) \
                              .returns(:test => last_data)
        end
        d = s[:test]
        assert_equal(last_data, d, "OK reads: #{reads}, OK writes: #{writes}")
        reads += 1
      end
      operation = rand(5) == 0 ? :write : :read
    end
  end



  private
  def obtain_session_options
    options = { 'database_manager' => CGI::Session::MemCacheStore,
                'session_key' => '_test_app_session'
              }
    # if don't have running memcache server we use mock instead
    unless CACHE
      options['cache'] = c = mock
      c.stubs(:[]).with(regexp_matches(SESSION_KEY_RE))
      c.stubs(:get).with(regexp_matches(SESSION_KEY_RE)) \
                   .returns(Hash.new)
      c.stubs(:add).with(regexp_matches(SESSION_KEY_RE),
                         instance_of(Hash),
                         0)
    end
    options
  end


  def new_session(options = {})
    with_cgi do |cgi|
      @options = obtain_session_options.merge(options)
      session = CGI::Session.new(cgi, @options)
      yield session if block_given?
      return session
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

end # defined? MemCache
end # uses_mocha
