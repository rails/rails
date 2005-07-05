# The filename begins with "aaa" to ensure this is the first test.
require 'abstract_unit'

class CreateTablesTest < Test::Unit::TestCase
  def setup
    @base_path = "#{File.dirname(__FILE__)}/fixtures/db_definitions"
  end

  def test_drop_and_create_main_tables
    recreate ActiveRecord::Base
    assert true
  end
  
  def test_drop_and_create_courses_table
    recreate Course, '2'
    assert true
  end

  private
    def recreate(base, suffix = nil)
      connection = base.connection
      adapter_name = connection.adapter_name.downcase + suffix.to_s
      execute_sql_file "#{@base_path}/#{adapter_name}.drop.sql", connection
      execute_sql_file "#{@base_path}/#{adapter_name}.sql", connection
    end

    def execute_sql_file(path, connection)
      File.read(path).split(';').each_with_index do |sql, i|
        begin
          connection.execute("\n\n-- statement ##{i}\n#{sql}\n") unless sql.blank?
        rescue ActiveRecord::StatementInvalid
          #$stderr.puts "warning: #{$!}"
        end
      end
    end
end
