require "#{File.dirname(__FILE__)}/../abstract_unit"

class RawPostDataTest < Test::Unit::TestCase
  def setup
    ENV.delete('RAW_POST_DATA')
    @request_body = 'a=1'
  end

  def test_post_with_urlencoded_body
    ENV['REQUEST_METHOD'] = 'POST'
    ENV['CONTENT_TYPE'] = ' apPlication/x-Www-form-urlEncoded; charset=utf-8'
    assert_equal ['1'], cgi.params['a']
    assert_raw_post_data
  end

  def test_post_with_empty_content_type_treated_as_urlencoded
    ENV['REQUEST_METHOD'] = 'POST'
    ENV['CONTENT_TYPE'] = ''
    assert_equal ['1'], cgi.params['a']
    assert_raw_post_data
  end

  def test_post_with_unrecognized_content_type_ignores_body
    ENV['REQUEST_METHOD'] = 'POST'
    ENV['CONTENT_TYPE'] = 'foo/bar'
    assert cgi.params.empty?
    assert_no_raw_post_data
  end

  def test_put_with_urlencoded_body
    ENV['REQUEST_METHOD'] = 'PUT'
    ENV['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    assert_equal ['1'], cgi.params['a']
    assert_raw_post_data
  end

  def test_put_with_empty_content_type_ignores_body
    ENV['REQUEST_METHOD'] = 'PUT'
    ENV['CONTENT_TYPE'] = ''
    assert cgi.params.empty?
    assert_no_raw_post_data
  end

  def test_put_with_unrecognized_content_type_ignores_body
    ENV['REQUEST_METHOD'] = 'PUT'
    ENV['CONTENT_TYPE'] = 'foo/bar'
    assert cgi.params.empty?
    assert_no_raw_post_data
  end

  private
    def cgi
      unless defined? @cgi
        ENV['CONTENT_LENGTH'] = @request_body.size.to_s
        @cgi = CGI.new('query', StringIO.new(@request_body.dup))
      end

      @cgi
    end

    def assert_raw_post_data
      assert_not_nil ENV['RAW_POST_DATA']
      assert ENV['RAW_POST_DATA'].frozen?
      assert_equal @request_body, ENV['RAW_POST_DATA']

      assert_equal '', cgi.stdinput.read
    end

    def assert_no_raw_post_data
      assert_nil ENV['RAW_POST_DATA']

      assert_equal @request_body, cgi.stdinput.read
    end
end
