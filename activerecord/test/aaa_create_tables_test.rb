# The filename begins with "aaa" to ensure this is the first test.
require 'abstract_unit'

class AAACreateTablesTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false

  def setup
    @base_path = "#{File.dirname(__FILE__)}/fixtures/db_definitions"
  end

  def test_drop_and_create_main_tables
    recreate ActiveRecord::Base unless use_migrations?
    assert true
  end

  def test_load_schema
    if ActiveRecord::Base.connection.supports_migrations?
      eval(File.read("#{File.dirname(__FILE__)}/fixtures/db_definitions/schema.rb"))
    else
      recreate ActiveRecord::Base, '3'
    end
    assert true
  end
  
  def test_drop_and_create_courses_table
    if Course.connection.supports_migrations?
      eval(File.read("#{File.dirname(__FILE__)}/fixtures/db_definitions/schema2.rb"))
    end
    recreate Course, '2' unless use_migrations_for_courses?
    assert true
  end

  private
    def use_migrations?
      unittest_sql_filename = ActiveRecord::Base.connection.adapter_name.downcase + ".sql"
      not File.exist? "#{@base_path}/#{unittest_sql_filename}"
    end

    def use_migrations_for_courses?
      unittest2_sql_filename = ActiveRecord::Base.connection.adapter_name.downcase + "2.sql"
      not File.exist? "#{@base_path}/#{unittest2_sql_filename}"
    end

    def recreate(base, suffix = nil)
      connection = base.connection
      adapter_name = connection.adapter_name.downcase + suffix.to_s
      execute_sql_file "#{@base_path}/#{adapter_name}.drop.sql", connection
      execute_sql_file "#{@base_path}/#{adapter_name}.sql", connection
    end

    def execute_sql_file(path, connection)
      # OpenBase has a different format for sql files
      if current_adapter?(:OpenBaseAdapter) then
          File.read(path).split("go").each_with_index do |sql, i|
            begin
              # OpenBase does not support comments embedded in sql
              connection.execute(sql,"SQL statement ##{i}") unless sql.blank?
            rescue ActiveRecord::StatementInvalid
              #$stderr.puts "warning: #{$!}"
            end
          end
      else
        File.read(path).split(';').each_with_index do |sql, i|
          begin
            connection.execute("\n\n-- statement ##{i}\n#{sql}\n") unless sql.blank?
          rescue ActiveRecord::StatementInvalid
            #$stderr.puts "warning: #{$!}"
          end
        end
      end
    end
end
