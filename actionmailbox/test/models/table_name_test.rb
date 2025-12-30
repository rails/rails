# frozen_string_literal: true

require "test_helper"

class ActionMailbox::TableNameTest < ActiveSupport::TestCase
  setup do
    @old_prefix = ActiveRecord::Base.table_name_prefix
    @old_suffix = ActiveRecord::Base.table_name_suffix

    ActiveRecord::Base.table_name_prefix = @prefix = "abc_"
    ActiveRecord::Base.table_name_suffix = @suffix = "_xyz"

    @models = [ActionMailbox::InboundEmail]
    @models.map(&:reset_table_name)
  end

  teardown do
    ActiveRecord::Base.table_name_prefix = @old_prefix
    ActiveRecord::Base.table_name_suffix = @old_suffix

    @models.map(&:reset_table_name)
  end

  test "prefix and suffix are added to the Action Mailbox tables' name" do
    assert_equal(
      "#{@prefix}action_mailbox_inbound_emails#{@suffix}",
       ActionMailbox::InboundEmail.table_name
    )
  end
end
