require "cases/helper"
require "models/author"
require "models/binary"
require "models/cake_designer"
require "models/chef"
require "models/comment"
require "models/edge"
require "models/essay"
require "models/post"
require "models/price_estimate"
require "models/topic"
require "models/treasure"
require "models/vertex"

module ActiveRecord
  class WhereTest < ActiveRecord::TestCase
    fixtures :posts, :edges, :authors, :binaries, :essays

    def test_where_copies_bind_params
      author = authors(:david)
      posts  = author.posts.where('posts.id != 1')
      joined = Post.where(id: posts)

      assert_operator joined.length, :>, 0

      joined.each { |post|
        assert_equal author, post.author
        assert_not_equal 1, post.id
      }
    end

    def test_rewhere_on_root
      assert_equal posts(:welcome), Post.rewhere(title: 'Welcome to the weblog').first
    end

    def test_belongs_to_shallow_where
      author = Author.new
      author.id = 1

      assert_equal Post.where(author_id: 1).to_sql, Post.where(author: author).to_sql
    end

    def test_belongs_to_nil_where
      assert_equal Post.where(author_id: nil).to_sql, Post.where(author: nil).to_sql
    end

    def test_belongs_to_array_value_where
      assert_equal Post.where(author_id: [1,2]).to_sql, Post.where(author: [1,2]).to_sql
    end

    def test_belongs_to_nested_relation_where
      expected = Post.where(author_id: Author.where(id: [1,2])).to_sql
      actual   = Post.where(author:    Author.where(id: [1,2])).to_sql

      assert_equal expected, actual
    end

    def test_belongs_to_nested_where
      parent = Comment.new
      parent.id = 1

      expected = Post.where(comments: { parent_id: 1 }).joins(:comments)
      actual   = Post.where(comments: { parent: parent }).joins(:comments)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_belongs_to_nested_where_with_relation
      author = authors(:david)

      expected = Author.where(id: author ).joins(:posts)
      actual   = Author.where(posts: { author_id: Author.where(id: author.id) }).joins(:posts)

      assert_equal expected.to_a, actual.to_a
    end

    def test_polymorphic_shallow_where
      treasure = Treasure.new
      treasure.id = 1

      expected = PriceEstimate.where(estimate_of_type: 'Treasure', estimate_of_id: 1)
      actual   = PriceEstimate.where(estimate_of: treasure)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_nested_array_where
      treasure = Treasure.new
      treasure.id = 1
      hidden = HiddenTreasure.new
      hidden.id = 2

      expected = PriceEstimate.where(estimate_of_type: 'Treasure', estimate_of_id: [treasure, hidden])
      actual   = PriceEstimate.where(estimate_of: [treasure, hidden])

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_empty_array_where
      treasure = Treasure.new
      treasure.id = 1
      hidden = HiddenTreasure.new
      hidden.id = 2

      expected = PriceEstimate.where("1=0")
      actual   = PriceEstimate.where(estimate_of: [])

      assert_equal expected.to_a, actual.to_a
    end

    def test_polymorphic_nested_relation_where
      expected = PriceEstimate.where(estimate_of_type: 'Treasure', estimate_of_id: Treasure.where(id: [1,2]))
      actual   = PriceEstimate.where(estimate_of: Treasure.where(id: [1,2]))

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_sti_shallow_where
      treasure = HiddenTreasure.new
      treasure.id = 1

      expected = PriceEstimate.where(estimate_of_type: 'Treasure', estimate_of_id: 1)
      actual   = PriceEstimate.where(estimate_of: treasure)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_nested_where
      thing = Post.new
      thing.id = 1

      expected = Treasure.where(price_estimates: { thing_type: 'Post', thing_id: 1 }).joins(:price_estimates)
      actual   = Treasure.where(price_estimates: { thing: thing }).joins(:price_estimates)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_sti_nested_where
      treasure = HiddenTreasure.new
      treasure.id = 1

      expected = Treasure.where(price_estimates: { estimate_of_type: 'Treasure', estimate_of_id: 1 }).joins(:price_estimates)
      actual   = Treasure.where(price_estimates: { estimate_of: treasure }).joins(:price_estimates)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_decorated_polymorphic_where
      treasure_decorator = Struct.new(:model) do
        def self.method_missing(method, *args, &block)
          Treasure.send(method, *args, &block)
        end

        def is_a?(klass)
          model.is_a?(klass)
        end

        def method_missing(method, *args, &block)
          model.send(method, *args, &block)
        end
      end

      treasure = Treasure.new
      treasure.id = 1
      decorated_treasure = treasure_decorator.new(treasure)

      expected = PriceEstimate.where(estimate_of_type: 'Treasure', estimate_of_id: 1)
      actual   = PriceEstimate.where(estimate_of: decorated_treasure)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_aliased_attribute
      expected = Topic.where(heading: 'The First Topic')
      actual   = Topic.where(title: 'The First Topic')

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_where_error
      assert_raises(ActiveRecord::StatementInvalid) do
        Post.where(:id => { 'posts.author_id' => 10 }).first
      end
    end

    def test_where_with_table_name
      post = Post.first
      assert_equal post, Post.where(:posts => { 'id' => post.id }).first
    end

    def test_where_with_table_name_and_empty_hash
      assert_equal 0, Post.where(:posts => {}).count
    end

    def test_where_with_table_name_and_empty_array
      assert_equal 0, Post.where(:id => []).count
    end

    def test_where_with_empty_hash_and_no_foreign_key
      assert_equal 0, Edge.where(:sink => {}).count
    end

    def test_where_with_blank_conditions
      [[], {}, nil, ""].each do |blank|
        assert_equal 4, Edge.where(blank).order("sink_id").to_a.size
      end
    end

    def test_where_on_association_with_custom_primary_key
      author = authors(:david)
      essay = Essay.where(writer: author).first

      assert_equal essays(:david_modest_proposal), essay
    end

    def test_where_on_association_with_custom_primary_key_with_relation
      author = authors(:david)
      essay = Essay.where(writer: Author.where(id: author.id)).first

      assert_equal essays(:david_modest_proposal), essay
    end

    def test_where_on_association_with_relation_performs_subselect_not_two_queries
      author = authors(:david)

      assert_queries(1) do
        Essay.where(writer: Author.where(id: author.id)).to_a
      end
    end

    def test_where_on_association_with_custom_primary_key_with_array_of_base
      author = authors(:david)
      essay = Essay.where(writer: [author]).first

      assert_equal essays(:david_modest_proposal), essay
    end

    def test_where_on_association_with_custom_primary_key_with_array_of_ids
      essay = Essay.where(writer: ["David"]).first

      assert_equal essays(:david_modest_proposal), essay
    end
  end
end
