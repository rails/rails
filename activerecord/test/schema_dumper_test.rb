require 'abstract_unit'
require "#{File.dirname(__FILE__)}/../lib/active_record/schema_dumper"
require 'stringio'

if ActiveRecord::Base.connection.respond_to?(:tables)

  class SchemaDumperTest < Test::Unit::TestCase
    def test_schema_dump
      stream = StringIO.new
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      output = stream.string

      assert_match %r{create_table "accounts"}, output
      assert_match %r{create_table "authors"}, output
      assert_no_match %r{create_table "schema_info"}, output
    end
  end

end
