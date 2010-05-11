require 'cases/helper'
require 'models/post'

class EachTest < ActiveRecord::TestCase
  fixtures :posts

  def setup
    @posts = Post.all(:order => "id asc")
    @total = Post.count
  end
  
  def test_each_should_excecute_one_query_per_batch
    assert_queries(Post.count + 1) do
      Post.find_each(:batch_size => 1) do |post|
        assert_kind_of Post, post
      end
    end
  end

  def test_each_should_raise_if_the_order_is_set
    assert_raise(RuntimeError) do
      Post.find_each(:order => "title") { |post| post }
    end
  end

  def test_each_should_raise_if_the_limit_is_set
    assert_raise(RuntimeError) do
      Post.find_each(:limit => 1) { |post| post }
    end
  end
  
  def test_find_in_batches_should_return_batches
    assert_queries(Post.count + 1) do
      Post.find_in_batches(:batch_size => 1) do |batch|
        assert_kind_of Array, batch
        assert_kind_of Post, batch.first
      end
    end
  end

  def test_find_in_batches_should_start_from_the_start_option
    assert_queries(Post.count) do
      Post.find_in_batches(:batch_size => 1, :start => 2) do |batch|
        assert_kind_of Array, batch
        assert_kind_of Post, batch.first
      end
    end
  end

  def test_find_in_batches_shouldnt_excute_query_unless_needed
    post_count = Post.count

    assert_queries(2) do
      Post.find_in_batches(:batch_size => post_count) {|batch| assert_kind_of Array, batch }
    end

    assert_queries(1) do
      Post.find_in_batches(:batch_size => post_count + 1) {|batch| assert_kind_of Array, batch }
    end
  end

  def test_find_in_batches_doesnt_clog_conditions
    Post.find_in_batches(:conditions => {:id => posts(:welcome).id}) do
      assert_nothing_raised { Post.find(posts(:thinking).id) }
    end
  end
  
  def test_each_should_raise_if_select_is_set_without_id
    assert_raise(RuntimeError) do
      Post.find_each(:select => :title, :batch_size => 1) { |post| post }
    end
  end

  def test_each_should_execute_if_id_is_in_select
    assert_queries(4) do
      Post.find_each(:select => "id, title, type", :batch_size => 2) do |post|
        assert_kind_of Post, post
      end
    end
  end
end