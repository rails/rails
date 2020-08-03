# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/binary"
require "models/cake_designer"
require "models/car"
require "models/chef"
require "models/post"
require "models/comment"
require "models/edge"
require "models/essay"
require "models/price_estimate"
require "models/topic"
require "models/treasure"
require "models/vertex"
require "support/stubs/strong_parameters"

module ActiveRecord
  class WhereTest < ActiveRecord::TestCase
    fixtures :posts, :comments, :edges, :authors, :author_addresses, :binaries, :essays, :cars, :treasures, :price_estimates, :topics

    def test_type_casting_nested_joins
      comment = comments(:eager_other_comment1)
      assert_equal [comment], Comment.joins(post: :author).where(authors: { id: "2-foo" })
    end

    def test_where_with_through_association
      assert_equal [authors(:david)], Author.joins(:comments).where(comments: comments(:greetings))
    end

    def test_type_cast_is_not_evaluated_at_relation_build_time
      posts = nil

      assert_not_called_on_instance_of(Type::Value, :cast) do
        posts = Post.where(id: "1-foo")
      end
      assert_equal [posts(:welcome)], posts.to_a

      assert_not_called_on_instance_of(Type::Value, :cast) do
        posts = Post.where(id: ["1-foo", "bar"])
      end
      assert_equal [posts(:welcome)], posts.to_a
    end

    def test_where_copies_bind_params
      author = authors(:david)
      posts  = author.posts.where("posts.id != 1")
      joined = Post.where(id: posts)

      assert_operator joined.length, :>, 0

      joined.each { |post|
        assert_equal author, post.author
        assert_not_equal 1, post.id
      }
    end

    def test_where_copies_bind_params_in_the_right_order
      author = authors(:david)
      posts = author.posts.where.not(id: 1)
      joined = Post.where(id: posts, title: posts.first.title)

      assert_equal joined, [posts.first]
    end

    def test_where_copies_arel_bind_params
      chef = Chef.create!
      CakeDesigner.create!(chef: chef)

      cake_designers = CakeDesigner.joins(:chef).where(chefs: { id: chef.id })
      chefs = Chef.where(employable: cake_designers)

      assert_equal [chef], chefs.to_a
    end

    def test_where_with_invalid_value
      topics(:first).update!(parent_id: 0, written_on: nil, bonus_time: nil, last_read: nil)
      assert_empty Topic.where(parent_id: Object.new)
      assert_empty Topic.where(parent_id: "not-a-number")
      assert_empty Topic.where(written_on: "")
      assert_empty Topic.where(bonus_time: "")
      assert_empty Topic.where(last_read: "")
    end

    def test_rewhere_on_root
      assert_equal posts(:welcome), Post.rewhere(title: "Welcome to the weblog").first
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
      assert_equal Post.where(author_id: [1, 2]).to_sql, Post.where(author: [1, 2]).to_sql
    end

    def test_belongs_to_nested_relation_where
      expected = Post.where(author_id: Author.where(id: [1, 2])).to_sql
      actual   = Post.where(author:    Author.where(id: [1, 2])).to_sql

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

      expected = Author.where(id: author).joins(:posts)
      actual   = Author.where(posts: { author_id: Author.where(id: author.id) }).joins(:posts)

      assert_equal expected.to_a, actual.to_a
    end

    def test_polymorphic_shallow_where
      treasure = Treasure.new
      treasure.id = 1

      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: 1)
      actual   = PriceEstimate.where(estimate_of: treasure)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_where_not_polymorphic_association
      sapphire = treasures(:sapphire)

      all = [treasures(:diamond), sapphire, cars(:honda), sapphire]
      assert_equal all, PriceEstimate.all.sort_by(&:id).map(&:estimate_of)

      actual = PriceEstimate.where.not(estimate_of: sapphire)
      only = PriceEstimate.where(estimate_of: sapphire)

      expected = all - [sapphire]
      assert_equal expected, actual.sort_by(&:id).map(&:estimate_of)
      assert_equal all - expected, only.sort_by(&:id).map(&:estimate_of)
    end

    def test_where_not_polymorphic_id_and_type_as_nand
      sapphire = treasures(:sapphire)

      all = [treasures(:diamond), sapphire, cars(:honda), sapphire]
      assert_equal all, PriceEstimate.all.sort_by(&:id).map(&:estimate_of)

      actual = PriceEstimate.where.yield_self do |where_chain|
        where_chain.stub(:not_behaves_as_nor?, false) do
          where_chain.not(estimate_of_type: sapphire.class.polymorphic_name, estimate_of_id: sapphire.id)
        end
      end
      only = PriceEstimate.where(estimate_of_type: sapphire.class.polymorphic_name, estimate_of_id: sapphire.id)

      expected = all - [sapphire]
      assert_equal expected, actual.sort_by(&:id).map(&:estimate_of)
      assert_equal all - expected, only.sort_by(&:id).map(&:estimate_of)
    end

    def test_where_not_polymorphic_id_and_type_as_nor_is_deprecated
      sapphire = treasures(:sapphire)

      all = [treasures(:diamond), sapphire, cars(:honda), sapphire]
      assert_equal all, PriceEstimate.all.sort_by(&:id).map(&:estimate_of)

      message = <<~MSG.squish
        NOT conditions will no longer behave as NOR in Rails 6.1.
        To continue using NOR conditions, NOT each condition individually
        (`.where.not(:estimate_of_type => ...).where.not(:estimate_of_id => ...)`).
      MSG
      actual = assert_deprecated(message) do
        PriceEstimate.where.not(estimate_of_type: sapphire.class.polymorphic_name, estimate_of_id: sapphire.id)
      end
      only = PriceEstimate.where(estimate_of_type: sapphire.class.polymorphic_name, estimate_of_id: sapphire.id)

      expected = all - [sapphire]
      # NOT (estimate_of_type = 'Treasure' OR estimate_of_id = sapphire.id) matches only `cars(:honda)` unfortunately.
      assert_not_equal expected, actual.sort_by(&:id).map(&:estimate_of)
      assert_equal all - expected, only.sort_by(&:id).map(&:estimate_of)
    end

    def test_where_not_association_as_nor_is_deprecated
      treasure = Treasure.create!(name: "my_treasure")
      PriceEstimate.create!(estimate_of: treasure, price: 2, currency: "USD")
      PriceEstimate.create!(estimate_of: treasure, price: 2, currency: "EUR")

      message = <<~MSG.squish
        NOT conditions will no longer behave as NOR in Rails 6.1.
        To continue using NOR conditions, NOT each condition individually
        (`.where.not(:price_estimates => { :price => ... }).where.not(:price_estimates => { :currency => ... })`).
      MSG
      assert_deprecated(message) do
        result = Treasure.joins(:price_estimates).where.not(price_estimates: { price: 2, currency: "USD" })

        assert_predicate result, :empty?
      end
    end

    def test_polymorphic_nested_array_where
      treasure = Treasure.new
      treasure.id = 1
      hidden = HiddenTreasure.new
      hidden.id = 2

      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: [treasure, hidden])
      actual   = PriceEstimate.where(estimate_of: [treasure, hidden])

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_nested_array_where_not
      treasure = treasures(:diamond)
      car = cars(:honda)

      expected = [price_estimates(:sapphire_1), price_estimates(:sapphire_2)]
      actual   = PriceEstimate.where.not(estimate_of: [treasure, car])

      assert_equal expected.sort_by(&:id), actual.sort_by(&:id)
    end

    def test_polymorphic_array_where_multiple_types
      treasure_1 = treasures(:diamond)
      treasure_2 = treasures(:sapphire)
      car = cars(:honda)

      expected = [price_estimates(:diamond), price_estimates(:sapphire_1), price_estimates(:sapphire_2), price_estimates(:honda)].sort
      actual = PriceEstimate.where(estimate_of: [treasure_1, treasure_2, car]).to_a.sort

      assert_equal expected, actual
    end

    def test_polymorphic_nested_relation_where
      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: Treasure.where(id: [1, 2]))
      actual   = PriceEstimate.where(estimate_of: Treasure.where(id: [1, 2]))

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_sti_shallow_where
      treasure = HiddenTreasure.new
      treasure.id = 1

      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: 1)
      actual   = PriceEstimate.where(estimate_of: treasure)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_nested_where
      thing = Post.new
      thing.id = 1

      expected = Treasure.where(price_estimates: { thing_type: "Post", thing_id: 1 }).joins(:price_estimates)
      actual   = Treasure.where(price_estimates: { thing: thing }).joins(:price_estimates)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_polymorphic_sti_nested_where
      treasure = HiddenTreasure.new
      treasure.id = 1

      expected = Treasure.where(price_estimates: { estimate_of_type: "Treasure", estimate_of_id: 1 }).joins(:price_estimates)
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

      expected = PriceEstimate.where(estimate_of_type: "Treasure", estimate_of_id: 1)
      actual   = PriceEstimate.where(estimate_of: decorated_treasure)

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_aliased_attribute
      expected = Topic.where(heading: "The First Topic")
      actual   = Topic.where(title: "The First Topic")

      assert_equal expected.to_sql, actual.to_sql
    end

    def test_where_error
      assert_nothing_raised do
        Post.where(id: { "posts.author_id" => 10 }).first
      end
    end

    def test_where_with_table_name
      post = Post.first
      assert_equal post, Post.where(posts: { "id" => post.id }).first
    end

    def test_where_with_table_name_and_empty_hash
      assert_equal 0, Post.where(posts: {}).count
    end

    def test_where_with_table_name_and_empty_array
      assert_equal 0, Post.where(id: []).count
    end

    def test_where_with_empty_hash_and_no_foreign_key
      assert_equal 0, Edge.where(sink: {}).count
    end

    def test_where_with_blank_conditions
      [[], {}, nil, ""].each do |blank|
        assert_equal 4, Edge.where(blank).order("sink_id").to_a.size
      end
    end

    def test_where_with_integer_for_string_column
      count = Post.where(title: 0).count
      assert_equal 0, count
    end

    def test_where_with_float_for_string_column
      count = Post.where(title: 0.0).count
      assert_equal 0, count
    end

    def test_where_with_boolean_for_string_column
      count = Post.where(title: false).count
      assert_equal 0, count
    end

    def test_where_with_decimal_for_string_column
      count = Post.where(title: BigDecimal(0)).count
      assert_equal 0, count
    end

    def test_where_with_duration_for_string_column
      count = Post.where(title: 0.seconds).count
      assert_equal 0, count
    end

    def test_where_with_integer_for_binary_column
      count = Binary.where(data: 0).count
      assert_equal 0, count
    end

    def test_where_with_emoji_for_binary_column
      Binary.create!(data: "🥦")
      assert Binary.where(data: ["🥦", "🍦"]).to_sql.include?("f09fa5a6")
      assert Binary.where(data: ["🥦", "🍦"]).to_sql.include?("f09f8da6")
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

    def test_where_with_relation_on_has_many_association
      essay = essays(:david_modest_proposal)
      author = Author.where(essays: Essay.where(id: essay.id)).first

      assert_equal authors(:david), author
    end

    def test_where_with_relation_on_has_one_association
      author = authors(:david)
      author_address = AuthorAddress.where(author: Author.where(id: author.id)).first
      assert_equal author_addresses(:david_address), author_address
    end

    def test_where_on_association_with_select_relation
      essay = Essay.where(author: Author.where(name: "David").select(:name)).take
      assert_equal essays(:david_modest_proposal), essay
    end

    def test_where_with_strong_parameters
      author = authors(:david)
      params = ProtectedParams.new(name: author.name)
      assert_raises(ActiveModel::ForbiddenAttributesError) { Author.where(params) }
      assert_equal author, Author.where(params.permit!).first
    end

    def test_where_with_large_number
      assert_equal [authors(:bob)], Author.where(id: [3, 9223372036854775808])
      assert_equal [authors(:bob)], Author.where(id: 3..9223372036854775808)
    end

    def test_to_sql_with_large_number
      assert_equal [authors(:bob)], Author.find_by_sql(Author.where(id: [3, 9223372036854775808]).to_sql)
      assert_equal [authors(:bob)], Author.find_by_sql(Author.where(id: 3..9223372036854775808).to_sql)
    end

    def test_where_with_unsupported_arguments
      assert_raises(ArgumentError) { Author.where(42) }
    end
  end
end
