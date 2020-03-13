# frozen_string_literal: true

require "active_support/current_attributes"

class ActionDispatch::Current < ActiveSupport::CurrentAttributes #:nodoc:
  # Set by ActionDispatch::CurrentRackEnv middleware.
  attribute :rack_env
end
