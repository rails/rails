require 'test/unit'
require 'cgi'
require 'stringio'
require File.dirname(__FILE__) + '/../../lib/action_controller/cgi_ext/raw_post_data_fix'

class RawPostDataTest < Test::Unit::TestCase
  def setup
    ENV.delete('RAW_POST_DATA')
    @request_body = 'a=1'
  end

  def test_post_with_urlencoded_body
    ENV['REQUEST_METHOD'] = 'POST'
    ENV['CONTENT_TYPE'] = ' apPlication/x-Www-form-urlEncoded; charset=utf-8'
    assert_equal ['1'], cgi_params['a']
    assert_has_raw_post_data
  end

  def test_post_with_empty_content_type_treated_as_urlencoded
    ENV['REQUEST_METHOD'] = 'POST'
    ENV['CONTENT_TYPE'] = ''
    assert_equal ['1'], cgi_params['a']
    assert_has_raw_post_data
  end

  def test_post_with_unrecognized_content_type_reads_body_but_doesnt_parse_params
    ENV['REQUEST_METHOD'] = 'POST'
    ENV['CONTENT_TYPE'] = 'foo/bar'
    assert cgi_params.empty?
    assert_has_raw_post_data
  end

  def test_put_with_urlencoded_body
    ENV['REQUEST_METHOD'] = 'PUT'
    ENV['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
    assert_equal ['1'], cgi_params['a']
    assert_has_raw_post_data
  end

  def test_put_with_empty_content_type_ignores_body
    ENV['REQUEST_METHOD'] = 'PUT'
    ENV['CONTENT_TYPE'] = ''
    assert cgi_params.empty?
    assert_has_raw_post_data
  end

  def test_put_with_unrecognized_content_type_ignores_body
    ENV['REQUEST_METHOD'] = 'PUT'
    ENV['CONTENT_TYPE'] = 'foo/bar'
    assert cgi_params.empty?
    assert_has_raw_post_data
  end

  private
    def cgi_params
      old_stdin, $stdin = $stdin, StringIO.new(@request_body.dup)
      ENV['CONTENT_LENGTH'] = $stdin.size.to_s
      CGI.new.params
    ensure
      $stdin = old_stdin
    end

    def assert_has_raw_post_data(expected_body = @request_body)
      assert_not_nil ENV['RAW_POST_DATA']
      assert ENV['RAW_POST_DATA'].frozen?
      assert_equal expected_body, ENV['RAW_POST_DATA']
    end
end
