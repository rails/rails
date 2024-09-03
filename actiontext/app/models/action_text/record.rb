# frozen_string_literal: true

# :markup: markdown

module ActionText
  class Record < ActiveRecord::Base # :nodoc:
    self.abstract_class = true

    connects_to(**ActionText.connects_to) if ActionText.connects_to
  end
end

ActiveSupport.run_load_hooks :action_text_record, ActionText::Record
