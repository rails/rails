require "cases/helper"
require 'models/post'
require 'models/person'
require 'models/reader'
require 'models/comment'

class HasManyThroughAssociationsTest < ActiveRecord::TestCase
  fixtures :posts, :readers, :people, :comments

  def test_associate_existing
    assert_queries(2) { posts(:thinking);people(:david) }

    posts(:thinking).people

    assert_queries(1) do
      posts(:thinking).people << people(:david)
    end
    
    assert_queries(1) do
      assert posts(:thinking).people.include?(people(:david))
    end
    
    assert posts(:thinking).reload.people(true).include?(people(:david))
  end

  def test_associating_new
    assert_queries(1) { posts(:thinking) }
    new_person = nil # so block binding catches it
    
    assert_queries(0) do
      new_person = Person.new :first_name => 'bob'
    end
    
    # Associating new records always saves them
    # Thus, 1 query for the new person record, 1 query for the new join table record
    assert_queries(2) do
      posts(:thinking).people << new_person
    end
    
    assert_queries(1) do
      assert posts(:thinking).people.include?(new_person)
    end
    
    assert posts(:thinking).reload.people(true).include?(new_person)
  end

  def test_associate_new_by_building
    assert_queries(1) { posts(:thinking) }
    
    assert_queries(0) do
      posts(:thinking).people.build(:first_name=>"Bob")
      posts(:thinking).people.new(:first_name=>"Ted")
    end
    
    # Should only need to load the association once
    assert_queries(1) do
      assert posts(:thinking).people.collect(&:first_name).include?("Bob")
      assert posts(:thinking).people.collect(&:first_name).include?("Ted")
    end
    
    # 2 queries for each new record (1 to save the record itself, 1 for the join model)
    #    * 2 new records = 4
    # + 1 query to save the actual post = 5
    assert_queries(5) do
      posts(:thinking).body += '-changed'
      posts(:thinking).save
    end
    
    assert posts(:thinking).reload.people(true).collect(&:first_name).include?("Bob")
    assert posts(:thinking).reload.people(true).collect(&:first_name).include?("Ted")
  end

  def test_delete_association
    assert_queries(2){posts(:welcome);people(:michael); }
    
    assert_queries(1) do
      posts(:welcome).people.delete(people(:michael))
    end
    
    assert_queries(1) do
      assert posts(:welcome).people.empty?
    end
    
    assert posts(:welcome).reload.people(true).empty?
  end

  def test_replace_association
    assert_queries(4){posts(:welcome);people(:david);people(:michael); posts(:welcome).people(true)}
    
    # 1 query to delete the existing reader (michael)
    # 1 query to associate the new reader (david)
    assert_queries(2) do
      posts(:welcome).people = [people(:david)]
    end
    
    assert_queries(0){
      assert posts(:welcome).people.include?(people(:david))
      assert !posts(:welcome).people.include?(people(:michael))
    }
    
    assert posts(:welcome).reload.people(true).include?(people(:david))
    assert !posts(:welcome).reload.people(true).include?(people(:michael))
  end

  def test_associate_with_create
    assert_queries(1) { posts(:thinking) }
    
    # 1 query for the new record, 1 for the join table record
    # No need to update the actual collection yet!
    assert_queries(2) do
      posts(:thinking).people.create(:first_name=>"Jeb")
    end
    
    # *Now* we actually need the collection so it's loaded
    assert_queries(1) do
      assert posts(:thinking).people.collect(&:first_name).include?("Jeb")
    end
    
    assert posts(:thinking).reload.people(true).collect(&:first_name).include?("Jeb")
  end

  def test_associate_with_create_and_no_options
    peeps = posts(:thinking).people.count
    posts(:thinking).people.create(:first_name => 'foo')
    assert_equal peeps + 1, posts(:thinking).people.count
  end

  def test_associate_with_create_exclamation_and_no_options
    peeps = posts(:thinking).people.count
    posts(:thinking).people.create!(:first_name => 'foo')
    assert_equal peeps + 1, posts(:thinking).people.count
  end

  def test_clear_associations
    assert_queries(2) { posts(:welcome);posts(:welcome).people(true) }
    
    assert_queries(1) do
      posts(:welcome).people.clear
    end
    
    assert_queries(0) do
      assert posts(:welcome).people.empty?
    end
    
    assert posts(:welcome).reload.people(true).empty?
  end

  def test_association_callback_ordering
    Post.reset_log
    log = Post.log
    post = posts(:thinking)

    post.people_with_callbacks << people(:michael)
    assert_equal [
      [:added, :before, "Michael"],
      [:added, :after, "Michael"]
    ], log.last(2)

    post.people_with_callbacks.push(people(:david), Person.create!(:first_name => "Bob"), Person.new(:first_name => "Lary"))
    assert_equal [
      [:added, :before, "David"],
      [:added, :after, "David"],
      [:added, :before, "Bob"],
      [:added, :after, "Bob"],
      [:added, :before, "Lary"],
      [:added, :after, "Lary"]
    ],log.last(6)

    post.people_with_callbacks.build(:first_name => "Ted")
    assert_equal [
      [:added, :before, "Ted"],
      [:added, :after, "Ted"]
    ], log.last(2)

    post.people_with_callbacks.create(:first_name => "Sam")
    assert_equal [
      [:added, :before, "Sam"],
      [:added, :after, "Sam"]
    ], log.last(2)

    post.people_with_callbacks = [people(:michael),people(:david), Person.new(:first_name => "Julian"), Person.create!(:first_name => "Roger")]
    assert_equal (%w(Ted Bob Sam Lary) * 2).sort, log[-12..-5].collect(&:last).sort
    assert_equal [
      [:added, :before, "Julian"],
      [:added, :after, "Julian"],
      [:added, :before, "Roger"],
      [:added, :after, "Roger"]
    ], log.last(4)

    post.people_with_callbacks.clear
    assert_equal (%w(Michael David Julian Roger) * 2).sort, log.last(8).collect(&:last).sort
  end

  def test_dynamic_find_should_respect_association_include
    # SQL error in sort clause if :include is not included
    # due to Unknown column 'comments.id'
    assert Person.find(1).posts_with_comments_sorted_by_comment_id.find_by_title('Welcome to the weblog')
  end

  def test_count_with_include_should_alias_join_table
    assert_equal 2, people(:michael).posts.count(:include => :readers)
  end

  def test_get_ids
    assert_equal [posts(:welcome).id, posts(:authorless).id].sort, people(:michael).post_ids.sort
  end

  def test_get_ids_for_loaded_associations
    person = people(:michael)
    person.posts(true)
    assert_queries(0) do
      person.post_ids
      person.post_ids
    end
  end

  def test_get_ids_for_unloaded_associations_does_not_load_them
    person = people(:michael)
    assert !person.posts.loaded?
    assert_equal [posts(:welcome).id, posts(:authorless).id].sort, person.post_ids.sort
    assert !person.posts.loaded?
  end

  uses_mocha 'mocking Tag.transaction' do
    def test_association_proxy_transaction_method_starts_transaction_in_association_class
      Tag.expects(:transaction)
      Post.find(:first).tags.transaction do
        # nothing
      end
    end
  end
end
