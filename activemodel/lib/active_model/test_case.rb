require "active_support/test_case"

module ActiveModel #:nodoc:
  class TestCase < ActiveSupport::TestCase #:nodoc:
    include ActiveModel::ValidationsRepairHelper
  end
end
