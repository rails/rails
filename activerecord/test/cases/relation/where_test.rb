require "cases/helper"
require 'models/author'
require 'models/price_estimate'
require 'models/treasure'
require 'models/post'

module ActiveRecord
  class WhereTest < ActiveRecord::TestCase
    fixtures :posts, :authors

    def test_belongs_to_shallow_where
      author = Post.first.author
      query_with_id = Post.where(:author_id => author)
      query_with_assoc = Post.where(:author => author)

      assert_equal query_with_id.to_sql, query_with_assoc.to_sql
    end

    def test_belongs_to_nested_where
      author = Post.first.author
      query_with_id = Author.where(:posts => {:author_id => author}).joins(:posts)
      query_with_assoc = Author.where(:posts => {:author => author}).joins(:posts)

      assert_equal query_with_id.to_sql, query_with_assoc.to_sql
    end

    def test_polymorphic_shallow_where
      treasure = Treasure.create(:name => 'gold coins')
      treasure.price_estimates << PriceEstimate.create(:price => 125)

      query_by_column = PriceEstimate.where(:estimate_of_type => 'Treasure', :estimate_of_id => treasure)
      query_by_model = PriceEstimate.where(:estimate_of => treasure)

      assert_equal query_by_column.to_sql, query_by_model.to_sql
    end

    def test_polymorphic_sti_shallow_where
      treasure = HiddenTreasure.create!(:name => 'gold coins')
      treasure.price_estimates << PriceEstimate.create!(:price => 125)

      query_by_column = PriceEstimate.where(:estimate_of_type => 'Treasure', :estimate_of_id => treasure)
      query_by_model = PriceEstimate.where(:estimate_of => treasure)

      assert_equal query_by_column.to_sql, query_by_model.to_sql
    end

    def test_polymorphic_nested_where
      estimate = PriceEstimate.create :price => 125
      treasure = Treasure.create :name => 'Booty'

      treasure.price_estimates << estimate

      query_by_column = Treasure.where(:price_estimates => {:estimate_of_type => 'Treasure', :estimate_of_id => treasure}).joins(:price_estimates)
      query_by_model = Treasure.where(:price_estimates => {:estimate_of => treasure}).joins(:price_estimates)

      assert_equal treasure, query_by_column.first
      assert_equal treasure, query_by_model.first
      assert_equal query_by_column.to_a, query_by_model.to_a
    end

    def test_polymorphic_sti_nested_where
      estimate = PriceEstimate.create :price => 125
      treasure = HiddenTreasure.create!(:name => 'gold coins')
      treasure.price_estimates << PriceEstimate.create!(:price => 125)

      treasure.price_estimates << estimate

      query_by_column = Treasure.where(:price_estimates => {:estimate_of_type => 'Treasure', :estimate_of_id => treasure}).joins(:price_estimates)
      query_by_model = Treasure.where(:price_estimates => {:estimate_of => treasure}).joins(:price_estimates)

      assert_equal treasure, query_by_column.first
      assert_equal treasure, query_by_model.first
      assert_equal query_by_column.to_a, query_by_model.to_a
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
  end
end
