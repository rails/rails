# frozen_string_literal: true

# :markup: markdown

require "active_support/test_case"

module ActionCable
  class TestCase < ActiveSupport::TestCase
    include ActionCable::TestHelper
  end
end

ActiveSupport.run_load_hooks(:action_cable_test_case, ActionCable::TestCase)
