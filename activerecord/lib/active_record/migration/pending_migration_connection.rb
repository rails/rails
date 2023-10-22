# frozen_string_literal: true

module ActiveRecord
  class PendingMigrationConnection # :nodoc:
    def self.establish_temporary_connection(db_config, &block)
      pool = ActiveRecord::Base.connection_handler.establish_connection(db_config, owner_name: self)

      yield pool.connection
    ensure
      ActiveRecord::Base.connection_handler.remove_connection_pool(self.name)
    end

    def self.primary_class?
      false
    end

    def self.current_preventing_writes
      false
    end
  end
end
