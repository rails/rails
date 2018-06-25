# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class Migration
        module Compatibility # :nodoc: all
          def self.find(version)
            version = version.to_s
            name = "V#{version.tr('.', '_')}"
            if const_defined?(name)
              return const_get(name)
            else
              ActiveRecord::Migration::Compatibility.find(version)
            end
          end

          class V5_1 < ActiveRecord::Migration::Compatibility::V5_1
            def change_column(table_name, column_name, type, options = {})
              clear_cache!
              sql = connection.send(:change_column_sql, table_name, column_name, type, options)
              execute "ALTER TABLE #{quote_table_name(table_name)} #{sql}"
              change_column_default(table_name, column_name, options[:default]) if options.key?(:default)
              change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
              change_column_comment(table_name, column_name, options[:comment]) if options.key?(:comment)
            end
          end

          class V5_0 < ActiveRecord::Migration::Compatibility::V5_0
            def create_table(table_name, options = {})
              if options[:id] == :uuid && !options.key?(:default)
                options[:default] = "uuid_generate_v4()"
              end

              unless adapter_name == "Mysql2" && options[:id] == :bigint
                if [:integer, :bigint].include?(options[:id]) && !options.key?(:default)
                  options[:default] = nil
                end
              end
              super
            end
          end
        end
      end
    end
  end
end
