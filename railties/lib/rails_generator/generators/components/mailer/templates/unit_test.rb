require File.dirname(__FILE__) + '/../test_helper'
require '<%= file_name %>'

class <%= class_name %>Test < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
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
      IO.readlines("#{FIXTURES_PATH}/<%= file_name %>/#{action}")
    end
end
