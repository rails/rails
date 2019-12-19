# frozen_string_literal: true

require "cases/helper"
require "models/professor"

if ActiveRecord::Base.connection.supports_foreign_tables?
  class ForeignTableTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    class ForeignProfessor < ActiveRecord::Base
      self.table_name = "foreign_professors"
    end

    class ForeignProfessorWithPk < ForeignProfessor
      self.primary_key = "id"
    end

    def setup
      @professor = Professor.create(name: "Nicola")

      @connection = ActiveRecord::Base.connection
      enable_extension!("postgres_fdw", @connection)

      foreign_db_config = ARTest.test_configuration_hashes["arunit2"]
      @connection.execute <<~SQL
        CREATE SERVER foreign_server
          FOREIGN DATA WRAPPER postgres_fdw
          OPTIONS (dbname '#{foreign_db_config["database"]}')
      SQL

      @connection.execute <<~SQL
        CREATE USER MAPPING FOR CURRENT_USER
          SERVER foreign_server
      SQL

      @connection.execute <<~SQL
        CREATE FOREIGN TABLE foreign_professors (
          id    int,
          name  character varying NOT NULL
        ) SERVER foreign_server OPTIONS (
          table_name 'professors'
        )
      SQL
    end

    def teardown
      disable_extension!("postgres_fdw", @connection)
      @connection.execute <<~SQL
        DROP SERVER IF EXISTS foreign_server CASCADE
      SQL
    end

    def test_table_exists
      table_name = ForeignProfessor.table_name
      assert_not ActiveRecord::Base.connection.table_exists?(table_name)
    end

    def test_foreign_tables_are_valid_data_sources
      table_name = ForeignProfessor.table_name
      assert @connection.data_source_exists?(table_name), "'#{table_name}' should be a data source"
    end

    def test_foreign_tables
      assert_equal ["foreign_professors"], @connection.foreign_tables
    end

    def test_foreign_table_exists
      assert @connection.foreign_table_exists?("foreign_professors")
      assert @connection.foreign_table_exists?(:foreign_professors)
      assert_not @connection.foreign_table_exists?("nonexistingtable")
      assert_not @connection.foreign_table_exists?("'")
      assert_not @connection.foreign_table_exists?(nil)
    end

    def test_attribute_names
      assert_equal ["id", "name"], ForeignProfessor.attribute_names
    end

    def test_attributes
      professor = ForeignProfessorWithPk.find(@professor.id)
      assert_equal @professor.attributes, professor.attributes
    end

    def test_does_not_have_a_primary_key
      assert_nil ForeignProfessor.primary_key
    end

    def test_insert_record
      # Explicit `id` here to avoid complex configurations to implicitly work with remote table
      ForeignProfessorWithPk.create!(id: 100, name: "Leonardo")

      professor = ForeignProfessorWithPk.last
      assert_equal "Leonardo", professor.name
    end

    def test_update_record
      professor = ForeignProfessorWithPk.find(@professor.id)
      professor.name = "Albert"
      professor.save!
      professor.reload
      assert_equal "Albert", professor.name
    end

    def test_delete_record
      professor = ForeignProfessorWithPk.find(@professor.id)
      assert_difference("ForeignProfessor.count", -1) { professor.destroy }
    end
  end
end
