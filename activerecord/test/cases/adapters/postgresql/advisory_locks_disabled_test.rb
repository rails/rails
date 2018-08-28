# frozen_string_literal: true

require "cases/helper"
require "cases/adapters/helpers/test_supports_advisory_locks"

class PostgresqlAdvisoryLocksDisabledTest < ActiveRecord::PostgreSQLTestCase
  include TestSupportsAdvisoryLocks
end
