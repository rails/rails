# frozen_string_literal: true

module ActiveRecord
  # This class is used to create a connection that we can use for advisory
  # locks. This will take out a "global" lock that can't be accidentally
  # removed if a new connection is established during a migration.
  class AdvisoryLockBase < ActiveRecord::Base # :nodoc:
    self.abstract_class = true

    self.connection_specification_name = "AdvisoryLockBase"

    class << self
      def _internal?
        true
      end
    end
  end
end
