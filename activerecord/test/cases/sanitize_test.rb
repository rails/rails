require "cases/helper"
require 'models/binary'
require 'models/author'
require 'models/post'

class SanitizeTest < ActiveRecord::TestCase
  def setup
  end

  def test_sanitize_sql_hash_handles_associations
    quoted_bambi = ActiveRecord::Base.connection.quote("Bambi")
    quoted_column_name = ActiveRecord::Base.connection.quote_column_name("name")
    quoted_table_name = ActiveRecord::Base.connection.quote_table_name("adorable_animals")
    expected_value = "#{quoted_table_name}.#{quoted_column_name} = #{quoted_bambi}"

    assert_deprecated do
      assert_equal expected_value, Binary.send(:sanitize_sql_hash, {adorable_animals: {name: 'Bambi'}})
    end
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
    david = Author.create!(name: 'David')
    david_posts = david.posts.select(:id)

    sub_query_pattern = /\(\bselect\b.*?\bwhere\b.*?\)/i

    select_author_sql = Post.send(:sanitize_sql_array, ['id in (?)', david_posts])
    assert_match(sub_query_pattern, select_author_sql, 'should sanitize `Relation` as subquery for bind variables')

    select_author_sql = Post.send(:sanitize_sql_array, ['id in (:post_ids)', post_ids: david_posts])
    assert_match(sub_query_pattern, select_author_sql, 'should sanitize `Relation` as subquery for named bind variables')
  end

  def test_sanitize_sql_array_handles_empty_statement
    select_author_sql = Post.send(:sanitize_sql_array, [''])
    assert_equal('', select_author_sql)
  end

  def test_sanitize_sql_like
    assert_equal '100\%', Binary.send(:sanitize_sql_like, '100%')
    assert_equal 'snake\_cased\_string', Binary.send(:sanitize_sql_like, 'snake_cased_string')
    assert_equal 'C:\\\\Programs\\\\MsPaint', Binary.send(:sanitize_sql_like, 'C:\\Programs\\MsPaint')
    assert_equal 'normal string 42', Binary.send(:sanitize_sql_like, 'normal string 42')
  end

  def test_sanitize_sql_like_with_custom_escape_character
    assert_equal '100!%', Binary.send(:sanitize_sql_like, '100%', '!')
    assert_equal 'snake!_cased!_string', Binary.send(:sanitize_sql_like, 'snake_cased_string', '!')
    assert_equal 'great!!', Binary.send(:sanitize_sql_like, 'great!', '!')
    assert_equal 'C:\\Programs\\MsPaint', Binary.send(:sanitize_sql_like, 'C:\\Programs\\MsPaint', '!')
    assert_equal 'normal string 42', Binary.send(:sanitize_sql_like, 'normal string 42', '!')
  end

  def test_sanitize_sql_like_example_use_case
    searchable_post = Class.new(Post) do
      def self.search(term)
        where("title LIKE ?", sanitize_sql_like(term, '!'))
      end
    end

    assert_sql(/LIKE '20!% !_reduction!_!!'/) do
      searchable_post.search("20% _reduction_!").to_a
    end
  end
end
