require File.dirname(__FILE__) + '/../test_helper'
require '<%= file_name %>'

class <%= class_name %>Test < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.to      = 'test@localhost'
    @expected.from    = 'test@localhost'
  end

<% for action in actions -%>
  def test_<%= action %>
    @expected.subject = '<%= class_name %>#<%= action %> test mail'
    @expected.body    = read_fixture('<%= action %>')
    @expected.date    = Time.now

    created = nil
    assert_nothing_raised { created = <%= class_name %>.create_<%= action %>(@expected.date) }
    assert_not_nil created
    assert_equal @expected.encoded, created.encoded

    assert_nothing_raised { <%= class_name %>.deliver_<%= action %>(@expected.date) }
    assert_equal @expected.encoded, ActionMailer::Base.deliveries.first.encoded
  end

<% end -%>
  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/<%= file_name %>/#{action}")
    end
end
