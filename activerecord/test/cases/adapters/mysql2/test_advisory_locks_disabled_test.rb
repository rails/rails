# frozen_string_literal: true

require "cases/helper"
require "cases/adapters/helpers/test_supports_advisory_locks"

class Mysql2AdvisoryLocksDisabledTest < ActiveRecord::Mysql2TestCase
  include TestSupportsAdvisoryLocks
end
