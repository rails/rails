require 'test/unit'
require 'cgi'
require 'stringio'
require File.dirname(__FILE__) + '/../../lib/action_controller/cgi_ext/raw_post_data_fix'

class RawPostDataTest < Test::Unit::TestCase
  def setup
    ENV['REQUEST_METHOD'] = 'POST'
    ENV['CONTENT_TYPE'] = ''
    ENV['CONTENT_LENGTH'] = '0'
  end

  def test_raw_post_data
    process_raw "action=create_customer&full_name=David%20Heinemeier%20Hansson&customerId=1"
  end

  private
    def process_raw(query_string)
      old_stdin = $stdin
      begin
        $stdin = StringIO.new(query_string.dup)
        ENV['CONTENT_LENGTH'] = $stdin.size.to_s
        CGI.new
        assert_not_nil ENV['RAW_POST_DATA']
        assert ENV['RAW_POST_DATA'].frozen?
        assert_equal query_string, ENV['RAW_POST_DATA']
      ensure
        $stdin = old_stdin
      end
    end
end
