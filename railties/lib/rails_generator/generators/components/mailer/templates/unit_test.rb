require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../test_helper'

class <%= class_name %>Test < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../fixtures'
  CHARSET = "utf-8"

  include ActionMailer::Quoting

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
    @expected.mime_version = '1.0'
  end

<% for action in actions -%>
  def test_<%= action %>
    @expected.subject = '<%= class_name %>#<%= action %>'
    @expected.body    = read_fixture('<%= action %>')
    @expected.date    = Time.now

    assert_equal @expected.encoded, <%= class_name %>.create_<%= action %>(@expected.date).encoded
  end

<% end -%>
  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/<%= file_path %>/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end
