require 'active_record'

module ActiveRecord
  class SchemaMigration < ActiveRecord::Base
    def self.table_name
      Base.table_name_prefix + 'schema_migrations' + Base.table_name_suffix
    end
  end
end
