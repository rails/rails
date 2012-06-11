require "cases/helper"
require 'models/post'

module ActiveRecord
  class WhereTest < ActiveRecord::TestCase
    fixtures :posts

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

    def test_where_with_table_name
      post = Post.first
      assert_equal post, Post.where(:posts => { 'id' => post.id }).first
    end
  end
end
