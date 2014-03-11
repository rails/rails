require 'active_record/associations/builder/has_and_belongs_to_many'
module ActiveRecord
  class Migration
    module JoinTable #:nodoc:
      private

      def find_join_table_name(table_1, table_2, options = {})
        options.delete(:table_name) || join_table_name(table_1, table_2)
      end

      def join_table_name(table_1, table_2)
        ActiveRecord::Associations::Builder::HasAndBelongsToMany::JoinTableResolver::KnownClass.join_table_name(table_1.to_s, table_2.to_s).to_sym
      end
    end
  end
end
