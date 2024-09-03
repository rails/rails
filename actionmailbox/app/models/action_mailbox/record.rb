# frozen_string_literal: true

module ActionMailbox
  class Record < ActiveRecord::Base # :nodoc:
    self.abstract_class = true

    connects_to(**ActionMailbox.connects_to) if ActionMailbox.connects_to
  end
end

ActiveSupport.run_load_hooks :action_mailbox_record, ActionMailbox::Record
