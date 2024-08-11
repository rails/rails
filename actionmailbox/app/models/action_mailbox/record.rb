# frozen_string_literal: true

module ActionMailbox
  class Record < ActiveRecord::Base # :nodoc:
    self.abstract_class = true

    connects_to(**Rails.configuration.action_mailbox.connects_to) if Rails.configuration.action_mailbox.connects_to
  end
end

ActiveSupport.run_load_hooks :action_mailbox_record, ActionMailbox::Record
