require 'active_record/scoping/default'
require 'active_record/scoping/named'
require 'active_record/base'

module ActiveRecord
  class SchemaMigration < ActiveRecord::Base
    def self.table_name
      Base.table_name_prefix + 'schema_migrations' + Base.table_name_suffix
    end

    def version
      super.to_i
    end
  end
end
