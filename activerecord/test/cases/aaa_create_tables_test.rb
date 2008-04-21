# The filename begins with "aaa" to ensure this is the first test.
require "cases/helper"

class AAACreateTablesTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def test_load_schema
    eval(File.read(SCHEMA_ROOT + "/schema.rb"))
    if File.exists?(adapter_specific_schema_file)
      eval(File.read(adapter_specific_schema_file))
    end
    assert true
  end

  def test_drop_and_create_courses_table
    eval(File.read(SCHEMA_ROOT + "/schema2.rb"))
    assert true
  end

  private
  def adapter_specific_schema_file
    SCHEMA_ROOT + '/' + ActiveRecord::Base.connection.adapter_name.downcase + '_specific_schema.rb'
  end
end
