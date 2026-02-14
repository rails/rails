# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class DumpSchemaTest < ActiveRecord::SQLite3TestCase
  include SchemaDumpingHelper

  # see test/schema/schema.rb for the list of tables created
  # create_table :parrots_pirates, id: false, force: true do |t|
  #   t.references :parrot, foreign_key: true
  #   t.references :pirate, foreign_key: true
  # end
  #
  # create_table :parrots_treasures, id: false, force: true do |t|
  #   t.references :parrot, foreign_key: true
  #   t.references :treasure, foreign_key: true
  # end
  def test_foreign_keys_are_emitted_after_their_referenced_tables
    connection = ActiveRecord::Base.connection
    assert_equal false, connection.requires_referential_integrity_at_definition?

    output = dump_all_table_schema

    # Check two tables to be sure we're not catching a random edge case of the last table in the dump
    table_position = output.index('create_table "parrot_treasures"')
    fk_parrots_position = output.index('add_foreign_key "parrot_treasures", "parrots"')
    fk_treasures_position = output.index('add_foreign_key "parrot_treasures", "treasures"')

    assert table_position, "parrot_treasures table should exist"
    assert fk_parrots_position, "foreign key to parrots should exist"
    assert fk_treasures_position, "foreign key to treasures should exist"
    assert table_position < fk_parrots_position, "foreign key should come after table"
    assert table_position < fk_treasures_position, "foreign key should come after table"

    table_position = output.index('create_table "parrots_pirates"')
    fk_parrots_position = output.index('add_foreign_key "parrots_pirates", "parrots"')
    fk_pirates_position = output.index('add_foreign_key "parrots_pirates", "pirates"')

    assert table_position, "parrots_pirates table should exist"
    assert fk_parrots_position, "foreign key to parrots should exist"
    assert fk_pirates_position, "foreign key to pirates should exist"
    assert table_position < fk_parrots_position, "foreign key should come after table"
    assert table_position < fk_pirates_position, "foreign key should come after table"
  end
end
