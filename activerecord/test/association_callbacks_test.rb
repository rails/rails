require 'abstract_unit'
require 'fixtures/post'
require 'fixtures/comment'
require 'fixtures/author'
require 'fixtures/category'
require 'fixtures/project'
require 'fixtures/developer'

class AssociationCallbacksTest < Test::Unit::TestCase
  fixtures :posts, :authors, :projects, :developers

  def setup
    @david = authors(:david)
    @thinking = posts(:thinking)
    @authorless = posts(:authorless)
    assert @david.post_log.empty?
  end
  
  def test_adding_macro_callbacks
    @david.posts_with_callbacks << @thinking
    assert_equal ["before_adding#{@thinking.id}", "after_adding#{@thinking.id}"], @david.post_log
    @david.posts_with_callbacks << @thinking
    assert_equal ["before_adding#{@thinking.id}", "after_adding#{@thinking.id}", "before_adding#{@thinking.id}", 
                  "after_adding#{@thinking.id}"], @david.post_log
  end
  
  def test_adding_with_proc_callbacks
    @david.posts_with_proc_callbacks << @thinking
    assert_equal ["before_adding#{@thinking.id}", "after_adding#{@thinking.id}"], @david.post_log
    @david.posts_with_proc_callbacks << @thinking
    assert_equal ["before_adding#{@thinking.id}", "after_adding#{@thinking.id}", "before_adding#{@thinking.id}", 
                  "after_adding#{@thinking.id}"], @david.post_log
  end
  
  def test_removing_with_macro_callbacks
    first_post, second_post = @david.posts_with_callbacks[0, 2]
    @david.posts_with_callbacks.delete(first_post)
    assert_equal ["before_removing#{first_post.id}", "after_removing#{first_post.id}"], @david.post_log
    @david.posts_with_callbacks.delete(second_post)
    assert_equal ["before_removing#{first_post.id}", "after_removing#{first_post.id}", "before_removing#{second_post.id}", 
                  "after_removing#{second_post.id}"], @david.post_log
  end

  def test_removing_with_proc_callbacks
    first_post, second_post = @david.posts_with_callbacks[0, 2]
    @david.posts_with_proc_callbacks.delete(first_post)
    assert_equal ["before_removing#{first_post.id}", "after_removing#{first_post.id}"], @david.post_log
    @david.posts_with_proc_callbacks.delete(second_post)
    assert_equal ["before_removing#{first_post.id}", "after_removing#{first_post.id}", "before_removing#{second_post.id}", 
                  "after_removing#{second_post.id}"], @david.post_log
  end
  
  def test_multiple_callbacks
    @david.posts_with_multiple_callbacks << @thinking
    assert_equal ["before_adding#{@thinking.id}", "before_adding_proc#{@thinking.id}", "after_adding#{@thinking.id}", 
                  "after_adding_proc#{@thinking.id}"], @david.post_log
    @david.posts_with_multiple_callbacks << @thinking
    assert_equal ["before_adding#{@thinking.id}", "before_adding_proc#{@thinking.id}", "after_adding#{@thinking.id}", 
                  "after_adding_proc#{@thinking.id}", "before_adding#{@thinking.id}", "before_adding_proc#{@thinking.id}", 
                  "after_adding#{@thinking.id}", "after_adding_proc#{@thinking.id}"], @david.post_log
  end
  
  def test_has_and_belongs_to_many_add_callback
    david = developers(:david)
    ar = projects(:active_record)
    assert ar.developers_log.empty?
    ar.developers_with_callbacks << david
    assert_equal ["before_adding#{david.id}", "after_adding#{david.id}"], ar.developers_log
    ar.developers_with_callbacks << david
    assert_equal ["before_adding#{david.id}", "after_adding#{david.id}", "before_adding#{david.id}", 
                  "after_adding#{david.id}"], ar.developers_log
  end
  
  def test_has_and_belongs_to_many_remove_callback
    david = developers(:david)
    jamis = developers(:jamis)
    activerecord = projects(:active_record)
    assert activerecord.developers_log.empty?
    activerecord.developers_with_callbacks.delete(david)
    assert_equal ["before_removing#{david.id}", "after_removing#{david.id}"], activerecord.developers_log
    
    activerecord.developers_with_callbacks.delete(jamis)
    assert_equal ["before_removing#{david.id}", "after_removing#{david.id}", "before_removing#{jamis.id}", 
                  "after_removing#{jamis.id}"], activerecord.developers_log
  end

  def test_has_and_belongs_to_many_remove_callback_on_clear
    activerecord = projects(:active_record)
    assert activerecord.developers_log.empty?
    if activerecord.developers_with_callbacks.size == 0
      activerecord.developers << developers(:david)
      activerecord.developers << developers(:jamis)
      activerecord.reload
      assert activerecord.developers_with_callbacks.size == 2
    end
    log_array = activerecord.developers_with_callbacks.collect {|d| ["before_removing#{d.id}","after_removing#{d.id}"]}.flatten.sort
    assert activerecord.developers_with_callbacks.clear
    assert_equal log_array, activerecord.developers_log.sort
  end
  
  def test_dont_add_if_before_callback_raises_exception
    assert !@david.unchangable_posts.include?(@authorless)
    begin
      @david.unchangable_posts << @authorless
    rescue Exception => e
    end
    assert @david.post_log.empty?
    assert !@david.unchangable_posts.include?(@authorless)
    @david.reload
    assert !@david.unchangable_posts.include?(@authorless)
  end
  
  def test_push_with_attributes
    assert_deprecated 'push_with_attributes' do
      david = developers(:david)
      activerecord = projects(:active_record)
      assert activerecord.developers_log.empty?
      activerecord.developers_with_callbacks.push_with_attributes(david, {})
      assert_equal ["before_adding#{david.id}", "after_adding#{david.id}"], activerecord.developers_log
      activerecord.developers_with_callbacks.push_with_attributes(david, {})
      assert_equal ["before_adding#{david.id}", "after_adding#{david.id}", "before_adding#{david.id}", 
                    "after_adding#{david.id}"], activerecord.developers_log
    end
  end
end

