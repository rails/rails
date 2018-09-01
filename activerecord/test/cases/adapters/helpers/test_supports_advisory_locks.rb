# frozen_string_literal: true

require "support/connection_helper"

module TestSupportsAdvisoryLocks
  include ConnectionHelper

  def test_supports_advisory_locks?
    assert ActiveRecord::Base.connection.supports_advisory_locks?

    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(
        orig_connection.merge(advisory_locks: false)
      )

      assert_not ActiveRecord::Base.connection.supports_advisory_locks?

      ActiveRecord::Base.establish_connection(
        orig_connection.merge(advisory_locks: true)
      )

      assert ActiveRecord::Base.connection.supports_advisory_locks?
    end
  end
end
