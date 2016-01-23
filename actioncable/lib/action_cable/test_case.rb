require "active_support/test_case"

module ActionCable
  class TestCase < ActiveSupport::TestCase
    include ActionCable::TestHelper
  end
end
