# frozen_string_literal: true

# :markup: markdown
module ActionMailbox
  class Record < ActiveRecord::Base # :nodoc:
    self.abstract_class = true
  end
end

ActiveSupport.run_load_hooks :action_mailbox_record, ActionMailbox::Record
