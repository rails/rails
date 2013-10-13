require "cases/helper"
require 'models/binary'

class SanitizeTest < ActiveRecord::TestCase
  def setup
  end

  def test_sanitize_sql_hash_handles_associations
    if current_adapter?(:MysqlAdapter, :Mysql2Adapter)
      expected_value = "`adorable_animals`.`name` = 'Bambi'"
    else
      expected_value =  "\"adorable_animals\".\"name\" = 'Bambi'"
    end

    assert_equal expected_value, Binary.send(:sanitize_sql_hash, {adorable_animals: {name: 'Bambi'}})
  end

  def test_sanitize_sql_array_handles_string_interpolation
    quoted_bambi = ActiveRecord::Base.connection.quote_string("Bambi")
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=%s", "Bambi"])
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=%s", "Bambi".mb_chars])
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote_string("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi_and_thumper}",Binary.send(:sanitize_sql_array, ["name=%s", "Bambi\nand\nThumper"])
    assert_equal "name=#{quoted_bambi_and_thumper}",Binary.send(:sanitize_sql_array, ["name=%s", "Bambi\nand\nThumper".mb_chars])
  end

  def test_sanitize_sql_array_handles_bind_variables
    quoted_bambi = ActiveRecord::Base.connection.quote("Bambi")
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi"])
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi".mb_chars])
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi_and_thumper}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi\nand\nThumper"])
    assert_equal "name=#{quoted_bambi_and_thumper}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi\nand\nThumper".mb_chars])
  end

  def test_sanitize_sql_array_handles_relations
    assert_match(/\(\bselect\b.*?\bwhere\b.*?\)/i,
      Binary.send(:sanitize_sql_array, ["id in (?)", Binary.where(id: 1)]),
      "should sanitize `Relation` as subquery")
  end
end
