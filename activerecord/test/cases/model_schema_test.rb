# frozen_string_literal: true

require "cases/helper"

class ActiveRecordModelSchemaTest < ActiveRecord::TestCase
  def test_derive_join_table_name
    first_table = "artists"
    second_table = "records"

    result = ActiveRecord::ModelSchema.derive_join_table_name(first_table, second_table)

    assert_equal "artists_records", result
  end

  def test_derive_join_table_name_with_common_prefix_removed
    first_table = "music_artists"
    second_table = "music_records"

    result = ActiveRecord::ModelSchema.derive_join_table_name(first_table, second_table)

    assert_equal "music_artists_records", result
  end
end
