# frozen_string_literal: true

require 'action_mailbox/test_helper'
require 'active_support/test_case'

module ActionMailbox
  class TestCase < ActiveSupport::TestCase
    include ActionMailbox::TestHelper
  end
end

ActiveSupport.run_load_hooks :action_mailbox_test_case, ActionMailbox::TestCase
