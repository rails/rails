require "cases/helper"
require 'models/post'
require 'models/comment'
require 'models/edge'
require 'models/author'
require 'models/organization'

module ActiveRecord
  class WhereTest < ActiveRecord::TestCase
    fixtures :posts, :edges, :organizations, :authors

    def test_where_error
      assert_raises(ActiveRecord::StatementInvalid) do
        Post.where(:id => { 'posts.author_id' => 10 }).first
      end
    end

    def test_where_error_with_hash
      assert_raises(ActiveRecord::StatementInvalid) do
        Post.where(:id => { :posts => {:author_id => 10} }).first
      end
    end

    def test_where_with_association_hash
      custom_join = "inner join authors on posts.author_id = authors.id " \
                    "inner join organizations on authors.organization_id = organizations.name"
      posts_count = Post.joins(custom_join).where(:authors => { :organizations => { :name => 'No Such Agency'} }).count
      assert_equal 5, posts_count
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
  end
end
