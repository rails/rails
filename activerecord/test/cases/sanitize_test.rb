# frozen_string_literal: true

require "cases/helper"
require "models/binary"
require "models/author"
require "models/post"
require "models/customer"

class SanitizeTest < ActiveRecord::TestCase
  def setup
  end

  def test_sanitize_sql_array_handles_string_interpolation
    quoted_bambi = ActiveRecord::Base.connection.quote_string("Bambi")
    assert_equal "name='#{quoted_bambi}'", Binary.sanitize_sql_array(["name='%s'", "Bambi"])
    assert_equal "name='#{quoted_bambi}'", Binary.sanitize_sql_array(["name='%s'", "Bambi".mb_chars])
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote_string("Bambi\nand\nThumper")
    assert_equal "name='#{quoted_bambi_and_thumper}'", Binary.sanitize_sql_array(["name='%s'", "Bambi\nand\nThumper"])
    assert_equal "name='#{quoted_bambi_and_thumper}'", Binary.sanitize_sql_array(["name='%s'", "Bambi\nand\nThumper".mb_chars])
  end

  def test_sanitize_sql_array_handles_bind_variables
    quoted_bambi = ActiveRecord::Base.connection.quote("Bambi")
    assert_equal "name=#{quoted_bambi}", Binary.sanitize_sql_array(["name=?", "Bambi"])
    assert_equal "name=#{quoted_bambi}", Binary.sanitize_sql_array(["name=?", "Bambi".mb_chars])
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi_and_thumper}", Binary.sanitize_sql_array(["name=?", "Bambi\nand\nThumper"])
    assert_equal "name=#{quoted_bambi_and_thumper}", Binary.sanitize_sql_array(["name=?", "Bambi\nand\nThumper".mb_chars])
  end

  def test_sanitize_sql_array_handles_named_bind_variables
    quoted_bambi = ActiveRecord::Base.connection.quote("Bambi")
    assert_equal "name=#{quoted_bambi}", Binary.sanitize_sql_array(["name=:name", name: "Bambi"])
    if current_adapter?(:Mysql2Adapter)
      assert_equal "name=#{quoted_bambi} AND id='1'", Binary.sanitize_sql_array(["name=:name AND id=:id", name: "Bambi", id: 1])
    else
      assert_equal "name=#{quoted_bambi} AND id=1", Binary.sanitize_sql_array(["name=:name AND id=:id", name: "Bambi", id: 1])
    end

    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi_and_thumper}", Binary.sanitize_sql_array(["name=:name", name: "Bambi\nand\nThumper"])
    assert_equal "name=#{quoted_bambi_and_thumper} AND name2=#{quoted_bambi_and_thumper}", Binary.sanitize_sql_array(["name=:name AND name2=:name", name: "Bambi\nand\nThumper"])
  end

  def test_sanitize_sql_array_handles_relations
    david = Author.create!(name: "David")
    david_posts = david.posts.select(:id)

    sub_query_pattern = /\(\bselect\b.*?\bwhere\b.*?\)/i

    select_author_sql = Post.sanitize_sql_array(["id in (?)", david_posts])
    assert_match(sub_query_pattern, select_author_sql, "should sanitize `Relation` as subquery for bind variables")

    select_author_sql = Post.sanitize_sql_array(["id in (:post_ids)", post_ids: david_posts])
    assert_match(sub_query_pattern, select_author_sql, "should sanitize `Relation` as subquery for named bind variables")
  end

  def test_sanitize_sql_array_handles_empty_statement
    select_author_sql = Post.sanitize_sql_array([""])
    assert_equal("", select_author_sql)
  end

  def test_sanitize_sql_like
    assert_equal '100\%', Binary.sanitize_sql_like("100%")
    assert_equal 'snake\_cased\_string', Binary.sanitize_sql_like("snake_cased_string")
    assert_equal 'C:\\\\Programs\\\\MsPaint', Binary.sanitize_sql_like('C:\\Programs\\MsPaint')
    assert_equal "normal string 42", Binary.sanitize_sql_like("normal string 42")
  end

  def test_sanitize_sql_like_with_custom_escape_character
    assert_equal "100!%", Binary.sanitize_sql_like("100%", "!")
    assert_equal "snake!_cased!_string", Binary.sanitize_sql_like("snake_cased_string", "!")
    assert_equal "great!!", Binary.sanitize_sql_like("great!", "!")
    assert_equal 'C:\\Programs\\MsPaint', Binary.sanitize_sql_like('C:\\Programs\\MsPaint', "!")
    assert_equal "normal string 42", Binary.sanitize_sql_like("normal string 42", "!")
  end

  def test_sanitize_sql_like_example_use_case
    searchable_post = Class.new(Post) do
      def self.search_as_method(term)
        where("title LIKE ?", sanitize_sql_like(term, "!"))
      end

      scope :search_as_scope, -> (term) {
        where("title LIKE ?", sanitize_sql_like(term, "!"))
      }
    end

    assert_sql(/LIKE '20!% !_reduction!_!!'/) do
      searchable_post.search_as_method("20% _reduction_!").to_a
    end

    assert_sql(/LIKE '20!% !_reduction!_!!'/) do
      searchable_post.search_as_scope("20% _reduction_!").to_a
    end
  end

  def test_disallow_raw_sql_with_unknown_attribute_string
    assert_raise(ActiveRecord::UnknownAttributeReference) { Binary.disallow_raw_sql!(["field(id, ?)"]) }
  end

  def test_disallow_raw_sql_with_unknown_attribute_sql_literal
    assert_nothing_raised { Binary.disallow_raw_sql!([Arel.sql("field(id, ?)")]) }
  end

  def test_bind_arity
    assert_nothing_raised                                { bind "" }
    assert_raise(ActiveRecord::PreparedStatementInvalid) { bind "", 1 }

    assert_raise(ActiveRecord::PreparedStatementInvalid) { bind "?" }
    assert_nothing_raised                                { bind "?", 1 }
    assert_raise(ActiveRecord::PreparedStatementInvalid) { bind "?", 1, 1 }
  end

  def test_named_bind_variables
    if current_adapter?(:Mysql2Adapter)
      assert_equal "'1'", bind(":a", a: 1) # ' ruby-mode
      assert_equal "'1' '1'", bind(":a :a", a: 1)  # ' ruby-mode
    else
      assert_equal "1", bind(":a", a: 1) # ' ruby-mode
      assert_equal "1 1", bind(":a :a", a: 1)  # ' ruby-mode
    end

    assert_nothing_raised { bind("'+00:00'", foo: "bar") }
  end

  def test_named_bind_arity
    assert_nothing_raised                                { bind "name = :name", name: "37signals" }
    assert_nothing_raised                                { bind "name = :name", name: "37signals", id: 1 }
    assert_raise(ActiveRecord::PreparedStatementInvalid) { bind "name = :name", id: 1 }
  end

  class SimpleEnumerable
    include Enumerable

    def initialize(ary)
      @ary = ary
    end

    def each(&b)
      @ary.each(&b)
    end
  end

  def test_bind_enumerable
    quoted_abc = %(#{ActiveRecord::Base.connection.quote('a')},#{ActiveRecord::Base.connection.quote('b')},#{ActiveRecord::Base.connection.quote('c')})

    if current_adapter?(:Mysql2Adapter)
      assert_equal "'1','2','3'", bind("?", [1, 2, 3])
    else
      assert_equal "1,2,3", bind("?", [1, 2, 3])
    end
    assert_equal quoted_abc, bind("?", %w(a b c))

    if current_adapter?(:Mysql2Adapter)
      assert_equal "'1','2','3'", bind(":a", a: [1, 2, 3])
    else
      assert_equal "1,2,3", bind(":a", a: [1, 2, 3])
    end
    assert_equal quoted_abc, bind(":a", a: %w(a b c)) # '

    if current_adapter?(:Mysql2Adapter)
      assert_equal "'1','2','3'", bind("?", SimpleEnumerable.new([1, 2, 3]))
    else
      assert_equal "1,2,3", bind("?", SimpleEnumerable.new([1, 2, 3]))
    end
    assert_equal quoted_abc, bind("?", SimpleEnumerable.new(%w(a b c)))

    if current_adapter?(:Mysql2Adapter)
      assert_equal "'1','2','3'", bind(":a", a: SimpleEnumerable.new([1, 2, 3]))
    else
      assert_equal "1,2,3", bind(":a", a: SimpleEnumerable.new([1, 2, 3]))
    end
    assert_equal quoted_abc, bind(":a", a: SimpleEnumerable.new(%w(a b c))) # '
  end

  def test_bind_empty_enumerable
    quoted_nil = ActiveRecord::Base.connection.quote(nil)
    assert_equal quoted_nil, bind("?", [])
    assert_equal " in (#{quoted_nil})", bind(" in (?)", [])
    assert_equal "foo in (#{quoted_nil})", bind("foo in (?)", [])
  end

  def test_bind_range
    quoted_abc = %(#{ActiveRecord::Base.connection.quote('a')},#{ActiveRecord::Base.connection.quote('b')},#{ActiveRecord::Base.connection.quote('c')})
    if current_adapter?(:Mysql2Adapter)
      assert_equal "'0'", bind("?", 0..0)
      assert_equal "'1','2','3'", bind("?", 1..3)
    else
      assert_equal "0", bind("?", 0..0)
      assert_equal "1,2,3", bind("?", 1..3)
    end
    assert_equal quoted_abc, bind("?", "a"..."d")
  end

  def test_bind_empty_range
    quoted_nil = ActiveRecord::Base.connection.quote(nil)
    assert_equal quoted_nil, bind("?", 0...0)
    assert_equal quoted_nil, bind("?", "a"..."a")
  end

  def test_bind_empty_string
    quoted_empty = ActiveRecord::Base.connection.quote("")
    assert_equal quoted_empty, bind("?", "")
  end

  def test_bind_chars
    quoted_bambi = ActiveRecord::Base.connection.quote("Bambi")
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi}", bind("name=?", "Bambi")
    assert_equal "name=#{quoted_bambi_and_thumper}", bind("name=?", "Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi}", bind("name=?", "Bambi".mb_chars)
    assert_equal "name=#{quoted_bambi_and_thumper}", bind("name=?", "Bambi\nand\nThumper".mb_chars)
  end

  def test_named_bind_with_postgresql_type_casts
    l = Proc.new { bind(":a::integer '2009-01-01'::date", a: "10") }
    assert_nothing_raised(&l)
    assert_equal "#{ActiveRecord::Base.connection.quote('10')}::integer '2009-01-01'::date", l.call
  end

  private
    def bind(statement, *vars)
      if vars.first.is_a?(Hash)
        ActiveRecord::Base.send(:replace_named_bind_variables, statement, vars.first)
      else
        ActiveRecord::Base.send(:replace_bind_variables, statement, vars)
      end
    end
end
