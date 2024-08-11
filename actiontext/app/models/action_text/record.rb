# frozen_string_literal: true

# :markup: markdown

module ActionText
  class Record < ActiveRecord::Base # :nodoc:
    self.abstract_class = true

    connects_to(**Rails.configuration.action_text.connects_to) if Rails.configuration.action_text.connects_to
  end
end

ActiveSupport.run_load_hooks :action_text_record, ActionText::Record
