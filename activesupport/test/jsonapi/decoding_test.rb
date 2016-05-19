require 'abstract_unit'
require 'active_support/jsonapi'

class TestJSONAPIDecoding < ActiveSupport::TestCase
  TESTS = {
    %({"data": {"id": "1", "type": "posts"}}) => { "_type" => "posts", "id" => "1" },
    %({"data": {"id": "1", "type": "posts", "attributes": {"title": "hello", "date": "today"}}}) => { "_type" => "posts", "id" => "1", "title" => "hello", "date" => "today" },
    %({"data": {"id": "1", "type": "posts", "relationships": {"author": {"data": {"type": "users", "id": "2"}}, "journal": {"data": null}, "comments": {"data": [{"type":"comments", "id":"3"},{"type":"comments","id":"4"}]}}}}) => { "_type" => "posts", "id" => "1", "author_id" => "2", "author_type" => "User", "journal_id" => nil, "comment_ids" => ["3", "4"], "comment_types" => ["Comment", "Comment"]  }
  }

  TESTS.each_with_index do |(json, expected), index|
    test "json decodes #{index}" do
      silence_warnings do
        assert_equal expected, ActiveSupport::JSONAPI.decode(json), "JSONAPI decoding \
          failed for #{json}"
      end
    end
  end

  def test_failed_json_decoding
#    assert_raise(ActiveSupport::JSON.parse_error) { ActiveSupport::JSON.decode(%(undefined)) }
#    assert_raise(ActiveSupport::JSON.parse_error) { ActiveSupport::JSON.decode(%({a: 1})) }
#    assert_raise(ActiveSupport::JSON.parse_error) { ActiveSupport::JSON.decode(%({: 1})) }
#    assert_raise(ActiveSupport::JSON.parse_error) { ActiveSupport::JSON.decode(%()) }
  end

  def test_cannot_pass_unsupported_options
    assert_raise(ArgumentError) { ActiveSupport::JSONAPI.decode("", create_additions: true) }
  end
end
