require 'generators/named_base'
require 'generators/migration'
require 'active_record'

module ActiveRecord
  module Generators
    class Base < Rails::Generators::NamedBase
      include Rails::Generators::Migration

      protected

        # Implement the required interface for Rails::Generators::Migration.
        #
        def next_migration_number(dirname) #:nodoc:
          if ActiveRecord::Base.timestamped_migrations
            Time.now.utc.strftime("%Y%m%d%H%M%S")
          else
            "%.3d" % (current_migration_number(dirname) + 1)
          end
        end

    end
  end
end
