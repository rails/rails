require "cases/helper"
require 'models/post'
require 'models/comment'
require 'models/author'
require 'models/category'
require 'models/project'
require 'models/developer'

class AssociationCallbacksTest < ActiveRecord::TestCase
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

  def test_has_many_callbacks_with_create
    morten = Author.create :name => "Morten"
    post = morten.posts_with_proc_callbacks.create! :title => "Hello", :body => "How are you doing?"
    assert_equal ["before_adding<new>", "after_adding#{post.id}"], morten.post_log
  end

  def test_has_many_callbacks_with_create!
    morten = Author.create! :name => "Morten"
    post = morten.posts_with_proc_callbacks.create :title => "Hello", :body => "How are you doing?"
    assert_equal ["before_adding<new>", "after_adding#{post.id}"], morten.post_log
  end

  def test_has_many_callbacks_for_save_on_parent
    jack = Author.new :name => "Jack"
    post = jack.posts_with_callbacks.build :title => "Call me back!", :body => "Before you wake up and after you sleep"

    callback_log = ["before_adding<new>", "after_adding#{jack.posts_with_callbacks.first.id}"]
    assert_equal callback_log, jack.post_log
    assert jack.save
    assert_equal 1, jack.posts_with_callbacks.count
    assert_equal callback_log, jack.post_log
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

  def test_has_and_belongs_to_many_after_add_called_after_save
    ar = projects(:active_record)
    assert ar.developers_log.empty?
    alice = Developer.new(:name => 'alice')
    ar.developers_with_callbacks << alice
    assert_equal"after_adding#{alice.id}", ar.developers_log.last

    bob = ar.developers_with_callbacks.create(:name => 'bob')
    assert_equal "after_adding#{bob.id}", ar.developers_log.last

    ar.developers_with_callbacks.build(:name => 'charlie')
    assert_equal "after_adding<new>", ar.developers_log.last
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

  def test_has_many_and_belongs_to_many_callbacks_for_save_on_parent
    project = Project.new :name => "Callbacks"
    project.developers_with_callbacks.build :name => "Jack", :salary => 95000

    callback_log = ["before_adding<new>", "after_adding<new>"]
    assert_equal callback_log, project.developers_log
    assert project.save
    assert_equal 1, project.developers_with_callbacks.size
    assert_equal callback_log, project.developers_log
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
end
