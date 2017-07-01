require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.connection.supports_extensions?
  class PostgresqlCitextTest < ActiveRecord::PostgreSQLTestCase
    include SchemaDumpingHelper
    class Citext < ActiveRecord::Base
      self.table_name = "citexts"
    end

    def setup
      @connection = ActiveRecord::Base.connection

      enable_extension!("citext", @connection)

      @connection.create_table("citexts") do |t|
        t.citext "cival"
      end
    end

    teardown do
      @connection.drop_table "citexts", if_exists: true
      disable_extension!("citext", @connection)
    end

    def test_citext_enabled
      assert @connection.extension_enabled?("citext")
    end

    def test_column
      column = Citext.columns_hash["cival"]
      assert_equal :citext, column.type
      assert_equal "citext", column.sql_type
      assert_not column.array?

      type = Citext.type_for_attribute("cival")
      assert_not type.binary?
    end

    def test_change_table_supports_json
      @connection.transaction do
        @connection.change_table("citexts") do |t|
          t.citext "username"
        end
        Citext.reset_column_information
        column = Citext.columns_hash["username"]
        assert_equal :citext, column.type

        raise ActiveRecord::Rollback # reset the schema change
      end
    ensure
      Citext.reset_column_information
    end

    def test_write
      x = Citext.new(cival: "Some CI Text")
      x.save!
      citext = Citext.first
      assert_equal "Some CI Text", citext.cival

      citext.cival = "Some NEW CI Text"
      citext.save!

      assert_equal "Some NEW CI Text", citext.reload.cival
    end

    def test_select_case_insensitive
      @connection.execute "insert into citexts (cival) values('Cased Text')"
      x = Citext.where(cival: "cased text").first
      assert_equal "Cased Text", x.cival
    end

    def test_schema_dump_with_shorthand
      output = dump_table_schema("citexts")
      assert_match %r[t\.citext "cival"], output
    end
  end
end
