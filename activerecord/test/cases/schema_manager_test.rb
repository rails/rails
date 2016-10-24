require 'cases/helper'
require 'support/schema_dumping_helper'

class FakeSchemaDumper
  def initialize(connection, options = {})
  end

  def dump(stream)
    stream.print 'Fake Schema Dump'
  end
end

class SchemaManagerTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  def test_schema_dumper_config
    previous_schema_dumper = ActiveRecord::Base.schema_dumper
    ActiveRecord::Base.schema_dumper = FakeSchemaDumper

    assert_equal dump_all_table_schema([]), 'Fake Schema Dump'
    ActiveRecord::Base.schema_dumper = previous_schema_dumper
  end
end
