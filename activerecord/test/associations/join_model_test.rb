require 'abstract_unit'
require 'fixtures/tag'
require 'fixtures/tagging'
require 'fixtures/post'
require 'fixtures/comment'
require 'fixtures/author'
require 'fixtures/category'
require 'fixtures/categorization'

class AssociationsJoinModelTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false
  fixtures :posts, :authors, :categories, :categorizations, :comments, :tags, :taggings, :author_favorites

  def test_has_many
    assert authors(:david).categories.include?(categories(:general))
  end

  def test_has_many_inherited
    assert authors(:mary).categories.include?(categories(:sti_test))
  end

  def test_inherited_has_many
    assert categories(:sti_test).authors.include?(authors(:mary))
  end

  def test_has_many_uniq_through_join_model
    assert_equal 2, authors(:mary).categorized_posts.size
    assert_equal 1, authors(:mary).unique_categorized_posts.size
  end

  def test_polymorphic_has_many
    assert posts(:welcome).taggings.include?(taggings(:welcome_general))
  end

  def test_polymorphic_has_one
    assert_equal taggings(:welcome_general), posts(:welcome).tagging
  end

  def test_polymorphic_belongs_to
    assert_equal posts(:welcome), posts(:welcome).taggings.first.taggable
  end

  def test_polymorphic_has_many_going_through_join_model
    assert_equal tags(:general), tag = posts(:welcome).tags.first
    assert_no_queries do
      tag.tagging
    end
  end

  def test_count_polymorphic_has_many
    assert_equal 1, posts(:welcome).taggings.count
    assert_equal 1, posts(:welcome).tags.count
  end

  def test_polymorphic_has_many_going_through_join_model_with_find
    assert_equal tags(:general), tag = posts(:welcome).tags.find(:first)
    assert_no_queries do
      tag.tagging
    end
  end

  def test_polymorphic_has_many_going_through_join_model_with_include_on_source_reflection
    assert_equal tags(:general), tag = posts(:welcome).funky_tags.first
    assert_no_queries do
      tag.tagging
    end
  end

  def test_polymorphic_has_many_going_through_join_model_with_include_on_source_reflection_with_find
    assert_equal tags(:general), tag = posts(:welcome).funky_tags.find(:first)
    assert_no_queries do
      tag.tagging
    end
  end

  def test_polymorphic_has_many_going_through_join_model_with_disabled_include
    assert_equal tags(:general), tag = posts(:welcome).tags.add_joins_and_select.first
    assert_queries 1 do
      tag.tagging
    end
  end

  def test_polymorphic_has_many_going_through_join_model_with_custom_select_and_joins
    assert_equal tags(:general), tag = posts(:welcome).tags.add_joins_and_select.first
    tag.author_id
  end

  def test_polymorphic_has_many_going_through_join_model_with_custom_foreign_key
    assert_equal tags(:misc), taggings(:welcome_general).super_tag
    assert_equal tags(:misc), posts(:welcome).super_tags.first
  end

  def test_polymorphic_has_many_create_model_with_inheritance_and_custom_base_class
    post = SubStiPost.create :title => 'SubStiPost', :body => 'SubStiPost body'
    assert_instance_of SubStiPost, post
    
    tagging = tags(:misc).taggings.create(:taggable => post)
    assert_equal "SubStiPost", tagging.taggable_type
  end

  def test_polymorphic_has_many_going_through_join_model_with_inheritance
    assert_equal tags(:general), posts(:thinking).tags.first
  end

  def test_polymorphic_has_many_going_through_join_model_with_inheritance_with_custom_class_name
    assert_equal tags(:general), posts(:thinking).funky_tags.first
  end

  def test_polymorphic_has_many_create_model_with_inheritance
    post = posts(:thinking)
    assert_instance_of SpecialPost, post
    
    tagging = tags(:misc).taggings.create(:taggable => post)
    assert_equal "Post", tagging.taggable_type
  end

  def test_polymorphic_has_one_create_model_with_inheritance
    tagging = tags(:misc).create_tagging(:taggable => posts(:thinking))
    assert_equal "Post", tagging.taggable_type
  end

  def test_set_polymorphic_has_many
    tagging = tags(:misc).taggings.create
    posts(:thinking).taggings << tagging
    assert_equal "Post", tagging.taggable_type
  end

  def test_set_polymorphic_has_one
    tagging = tags(:misc).taggings.create
    posts(:thinking).tagging = tagging
    assert_equal "Post", tagging.taggable_type
  end

  def test_create_polymorphic_has_many_with_scope
    old_count = posts(:welcome).taggings.count
    tagging = posts(:welcome).taggings.create(:tag => tags(:misc))
    assert_equal "Post", tagging.taggable_type
    assert_equal old_count+1, posts(:welcome).taggings.count
  end
  
  def test_create_bang_polymorphic_with_has_many_scope
    old_count = posts(:welcome).taggings.count
    tagging = posts(:welcome).taggings.create!(:tag => tags(:misc))
    assert_equal "Post", tagging.taggable_type
    assert_equal old_count+1, posts(:welcome).taggings.count
  end

  def test_create_polymorphic_has_one_with_scope
    old_count = Tagging.count
    tagging = posts(:welcome).tagging.create(:tag => tags(:misc))
    assert_equal "Post", tagging.taggable_type
    assert_equal old_count+1, Tagging.count
  end

  def test_delete_polymorphic_has_many_with_delete_all
    assert_equal 1, posts(:welcome).taggings.count
    posts(:welcome).taggings.first.update_attribute :taggable_type, 'PostWithHasManyDeleteAll'
    post = find_post_with_dependency(1, :has_many, :taggings, :delete_all)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count-1, Tagging.count
    assert_equal 0, posts(:welcome).taggings.count
  end

  def test_delete_polymorphic_has_many_with_destroy
    assert_equal 1, posts(:welcome).taggings.count
    posts(:welcome).taggings.first.update_attribute :taggable_type, 'PostWithHasManyDestroy'
    post = find_post_with_dependency(1, :has_many, :taggings, :destroy)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count-1, Tagging.count
    assert_equal 0, posts(:welcome).taggings.count
  end

  def test_delete_polymorphic_has_many_with_nullify
    assert_equal 1, posts(:welcome).taggings.count
    posts(:welcome).taggings.first.update_attribute :taggable_type, 'PostWithHasManyNullify'
    post = find_post_with_dependency(1, :has_many, :taggings, :nullify)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count, Tagging.count
    assert_equal 0, posts(:welcome).taggings.count
  end

  def test_delete_polymorphic_has_one_with_destroy
    assert posts(:welcome).tagging
    posts(:welcome).tagging.update_attribute :taggable_type, 'PostWithHasOneDestroy'
    post = find_post_with_dependency(1, :has_one, :tagging, :destroy)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count-1, Tagging.count
    assert_nil posts(:welcome).tagging(true)
  end

  def test_delete_polymorphic_has_one_with_nullify
    assert posts(:welcome).tagging
    posts(:welcome).tagging.update_attribute :taggable_type, 'PostWithHasOneNullify'
    post = find_post_with_dependency(1, :has_one, :tagging, :nullify)

    old_count = Tagging.count
    post.destroy
    assert_equal old_count, Tagging.count
    assert_nil posts(:welcome).tagging(true)
  end

  def test_has_many_with_piggyback
    assert_equal "2", categories(:sti_test).authors.first.post_id.to_s
  end

  def test_include_has_many_through
    posts              = Post.find(:all, :order => 'posts.id')
    posts_with_authors = Post.find(:all, :include => :authors, :order => 'posts.id')
    assert_equal posts.length, posts_with_authors.length
    posts.length.times do |i|
      assert_equal posts[i].authors.length, assert_no_queries { posts_with_authors[i].authors.length }
    end
  end

  def test_include_polymorphic_has_one
    post    = Post.find_by_id(posts(:welcome).id, :include => :tagging)
    tagging = taggings(:welcome_general)
    assert_no_queries do
      assert_equal tagging, post.tagging
    end
  end

  def test_include_polymorphic_has_many_through
    posts           = Post.find(:all, :order => 'posts.id')
    posts_with_tags = Post.find(:all, :include => :tags, :order => 'posts.id')
    assert_equal posts.length, posts_with_tags.length
    posts.length.times do |i|
      assert_equal posts[i].tags.length, assert_no_queries { posts_with_tags[i].tags.length }
    end
  end

  def test_include_polymorphic_has_many
    posts               = Post.find(:all, :order => 'posts.id')
    posts_with_taggings = Post.find(:all, :include => :taggings, :order => 'posts.id')
    assert_equal posts.length, posts_with_taggings.length
    posts.length.times do |i|
      assert_equal posts[i].taggings.length, assert_no_queries { posts_with_taggings[i].taggings.length }
    end
  end

  def test_has_many_find_all
    assert_equal [categories(:general)], authors(:david).categories.find(:all)
  end
  
  def test_has_many_find_first
    assert_equal categories(:general), authors(:david).categories.find(:first)
  end

  def test_has_many_with_hash_conditions
    assert_equal categories(:general), authors(:david).categories_like_general.find(:first)
  end
  
  def test_has_many_find_conditions
    assert_equal categories(:general), authors(:david).categories.find(:first, :conditions => "categories.name = 'General'")
    assert_equal nil, authors(:david).categories.find(:first, :conditions => "categories.name = 'Technology'")
  end
  
  def test_has_many_class_methods_called_by_method_missing
    assert_equal categories(:general), authors(:david).categories.find_all_by_name('General').first
#    assert_equal nil, authors(:david).categories.find_by_name('Technology')
  end

  def test_has_many_going_through_join_model_with_custom_foreign_key
    assert_equal [], posts(:thinking).authors
    assert_equal [authors(:mary)], posts(:authorless).authors
  end

  def test_belongs_to_polymorphic_with_counter_cache
    assert_equal 0, posts(:welcome)[:taggings_count]
    tagging = posts(:welcome).taggings.create(:tag => tags(:general))
    assert_equal 1, posts(:welcome, :reload)[:taggings_count]
    tagging.destroy
    assert posts(:welcome, :reload)[:taggings_count].zero?
  end

  def test_unavailable_through_reflection
    assert_raises (ActiveRecord::HasManyThroughAssociationNotFoundError) { authors(:david).nothings }
  end

  def test_has_many_through_join_model_with_conditions
    assert_equal [], posts(:welcome).invalid_taggings
    assert_equal [], posts(:welcome).invalid_tags
  end

  def test_has_many_polymorphic
    assert_raises ActiveRecord::HasManyThroughAssociationPolymorphicError do
      assert_equal [posts(:welcome), posts(:thinking)], tags(:general).taggables
    end
    assert_raises ActiveRecord::EagerLoadPolymorphicError do
      assert_equal [posts(:welcome), posts(:thinking)], tags(:general).taggings.find(:all, :include => :taggable)
    end
  end

  def test_has_many_through_has_many_find_all
    assert_equal comments(:greetings), authors(:david).comments.find(:all, :order => 'comments.id').first
  end

  def test_has_many_through_has_many_find_all_with_custom_class
    assert_equal comments(:greetings), authors(:david).funky_comments.find(:all, :order => 'comments.id').first
  end

  def test_has_many_through_has_many_find_first
    assert_equal comments(:greetings), authors(:david).comments.find(:first, :order => 'comments.id')
  end

  def test_has_many_through_has_many_find_conditions
    options = { :conditions => "comments.#{QUOTED_TYPE}='SpecialComment'", :order => 'comments.id' }
    assert_equal comments(:does_it_hurt), authors(:david).comments.find(:first, options)
  end

  def test_has_many_through_has_many_find_by_id
    assert_equal comments(:more_greetings), authors(:david).comments.find(2)
  end

  def test_has_many_through_polymorphic_has_one
    assert_raise(ActiveRecord::HasManyThroughSourceAssociationMacroError) { authors(:david).tagging }
  end

  def test_has_many_through_polymorphic_has_many
    assert_equal [taggings(:welcome_general), taggings(:thinking_general)], authors(:david).taggings.uniq.sort_by { |t| t.id }
  end

  def test_include_has_many_through_polymorphic_has_many
    author            = Author.find_by_id(authors(:david).id, :include => :taggings)
    expected_taggings = [taggings(:welcome_general), taggings(:thinking_general)]
    assert_no_queries do
      assert_equal expected_taggings, author.taggings.uniq.sort_by { |t| t.id }
    end
  end

  def test_has_many_through_has_many_through
    assert_raise(ActiveRecord::HasManyThroughSourceAssociationMacroError) { authors(:david).tags }
  end

  def test_has_many_through_habtm
    assert_raise(ActiveRecord::HasManyThroughSourceAssociationMacroError) { authors(:david).post_categories }
  end

  def test_eager_load_has_many_through_has_many
    author = Author.find :first, :conditions => ['name = ?', 'David'], :include => :comments, :order => 'comments.id'
    SpecialComment.new; VerySpecialComment.new
    assert_no_queries do
      assert_equal [1,2,3,5,6,7,8,9,10], author.comments.collect(&:id)
    end
  end
  
  def test_eager_load_has_many_through_has_many_with_conditions
    post = Post.find(:first, :include => :invalid_tags)
    assert_no_queries do
      post.invalid_tags
    end
  end

  def test_eager_belongs_to_and_has_one_not_singularized
    assert_nothing_raised do
      Author.find(:first, :include => :author_address)
      AuthorAddress.find(:first, :include => :author)
    end
  end

  def test_self_referential_has_many_through
    assert_equal [authors(:mary)], authors(:david).favorite_authors
    assert_equal [],               authors(:mary).favorite_authors
  end

  def test_add_to_self_referential_has_many_through
    new_author = Author.create(:name => "Bob")
    authors(:david).author_favorites.create :favorite_author => new_author
    assert_equal new_author, authors(:david).reload.favorite_authors.first
  end

  def test_has_many_through_uses_correct_attributes
    assert_nil posts(:thinking).tags.find_by_name("General").attributes["tag_id"]
  end

  def test_raise_error_when_adding_new_record_to_has_many_through
    assert_raise(ActiveRecord::HasManyThroughCantAssociateNewRecords) { posts(:thinking).tags << tags(:general).clone }
    assert_raise(ActiveRecord::HasManyThroughCantAssociateNewRecords) { posts(:thinking).clone.tags << tags(:general) }
    assert_raise(ActiveRecord::HasManyThroughCantAssociateNewRecords) { posts(:thinking).tags.build }
  end

  def test_create_associate_when_adding_to_has_many_through
    count = posts(:thinking).tags.count
    push = Tag.create!(:name => 'pushme')
    post_thinking = posts(:thinking)
    assert_nothing_raised { post_thinking.tags << push }
    assert_nil( wrong = post_thinking.tags.detect { |t| t.class != Tag },
                message = "Expected a Tag in tags collection, got #{wrong.class}.")
    assert_nil( wrong = post_thinking.taggings.detect { |t| t.class != Tagging },
                message = "Expected a Tagging in taggings collection, got #{wrong.class}.")
    assert_equal(count + 1, post_thinking.tags.size)
    assert_equal(count + 1, post_thinking.tags(true).size)

    assert_nothing_raised { post_thinking.tags.create!(:name => 'foo') }
    assert_nil( wrong = post_thinking.tags.detect { |t| t.class != Tag },
                message = "Expected a Tag in tags collection, got #{wrong.class}.")
    assert_nil( wrong = post_thinking.taggings.detect { |t| t.class != Tagging },
                message = "Expected a Tagging in taggings collection, got #{wrong.class}.")
    assert_equal(count + 2, post_thinking.tags.size)
    assert_equal(count + 2, post_thinking.tags(true).size)

    assert_nothing_raised { post_thinking.tags.concat(Tag.create!(:name => 'abc'), Tag.create!(:name => 'def')) }
    assert_nil( wrong = post_thinking.tags.detect { |t| t.class != Tag },
                message = "Expected a Tag in tags collection, got #{wrong.class}.")
    assert_nil( wrong = post_thinking.taggings.detect { |t| t.class != Tagging },
                message = "Expected a Tagging in taggings collection, got #{wrong.class}.")
    assert_equal(count + 4, post_thinking.tags.size)
    assert_equal(count + 4, post_thinking.tags(true).size)
  end

  def test_adding_junk_to_has_many_through_should_raise_type_mismatch
    assert_raise(ActiveRecord::AssociationTypeMismatch) { posts(:thinking).tags << "Uhh what now?" }
  end

  def test_adding_to_has_many_through_should_return_self
    tags = posts(:thinking).tags
    assert_equal tags, posts(:thinking).tags.push(tags(:general))
  end

  def test_delete_associate_when_deleting_from_has_many_through
    count = posts(:thinking).tags.count
    tags_before = posts(:thinking).tags
    tag = Tag.create!(:name => 'doomed')
    post_thinking = posts(:thinking)
    post_thinking.tags << tag
    assert_equal(count + 1, post_thinking.tags(true).size)

    assert_nothing_raised { post_thinking.tags.delete(tag) }    
    assert_equal(count, post_thinking.tags.size)
    assert_equal(count, post_thinking.tags(true).size)
    assert_equal(tags_before.sort, post_thinking.tags.sort)
  end

  def test_delete_associate_when_deleting_from_has_many_through_with_multiple_tags
    count = posts(:thinking).tags.count
    tags_before = posts(:thinking).tags
    doomed = Tag.create!(:name => 'doomed')
    doomed2 = Tag.create!(:name => 'doomed2')
    quaked = Tag.create!(:name => 'quaked')
    post_thinking = posts(:thinking)
    post_thinking.tags << doomed << doomed2
    assert_equal(count + 2, post_thinking.tags(true).size)

    assert_nothing_raised { post_thinking.tags.delete(doomed, doomed2, quaked) }    
    assert_equal(count, post_thinking.tags.size)
    assert_equal(count, post_thinking.tags(true).size)
    assert_equal(tags_before.sort, post_thinking.tags.sort)
  end

  def test_deleting_junk_from_has_many_through_should_raise_type_mismatch
    assert_raise(ActiveRecord::AssociationTypeMismatch) { posts(:thinking).tags.delete("Uhh what now?") }
  end

  def test_has_many_through_sum_uses_calculations
    assert_nothing_raised { authors(:david).comments.sum(:post_id) }
  end

  def test_has_many_through_has_many_with_sti
    assert_equal [comments(:does_it_hurt)], authors(:david).special_post_comments
  end

  private
    # create dynamic Post models to allow different dependency options
    def find_post_with_dependency(post_id, association, association_name, dependency)
      class_name = "PostWith#{association.to_s.classify}#{dependency.to_s.classify}"
      Post.find(post_id).update_attribute :type, class_name
      klass = Object.const_set(class_name, Class.new(ActiveRecord::Base))
      klass.set_table_name 'posts'
      klass.send(association, association_name, :as => :taggable, :dependent => dependency)
      klass.find(post_id)
    end
end
