# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/topic"
require "models/comment"
require "models/reply"
require "models/author"
require "models/developer"
require "models/computer"

class NamedScopingTest < ActiveRecord::TestCase
  fixtures :posts, :authors, :topics, :comments, :author_addresses

  def test_implements_enumerable
    assert_not_empty Topic.all

    assert_equal Topic.all.to_a, Topic.base
    assert_equal Topic.all.to_a, Topic.base.to_a
    assert_equal Topic.first,    Topic.base.first
    assert_equal Topic.all.to_a, Topic.base.map { |i| i }
  end

  def test_found_items_are_cached
    all_posts = Topic.base

    assert_queries(1) do
      all_posts.collect { true }
      all_posts.collect { true }
    end
  end

  def test_reload_expires_cache_of_found_items
    all_posts = Topic.base
    all_posts.to_a

    new_post = Topic.create!
    assert_not_includes all_posts, new_post
    assert_includes all_posts.reload, new_post
  end

  def test_delegates_finds_and_calculations_to_the_base_class
    assert_not_empty Topic.all

    assert_equal Topic.all.to_a,                Topic.base.to_a
    assert_equal Topic.first,                   Topic.base.first
    assert_equal Topic.count,                   Topic.base.count
    assert_equal Topic.average(:replies_count), Topic.base.average(:replies_count)
  end

  def test_calling_merge_at_first_in_scope
    Topic.class_eval do
      scope :calling_merge_at_first_in_scope, Proc.new { merge(Topic.replied) }
    end
    assert_equal Topic.calling_merge_at_first_in_scope.to_a, Topic.replied.to_a
  end

  def test_method_missing_priority_when_delegating
    klazz = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"
      scope :since, Proc.new { where("written_on >= ?", Time.now - 1.day) }
      scope :to,    Proc.new { where("written_on <= ?", Time.now) }
    end
    assert_equal klazz.to.since.to_a, klazz.since.to.to_a
  end

  def test_scope_should_respond_to_own_methods_and_methods_of_the_proxy
    assert_respond_to Topic.approved, :limit
    assert_respond_to Topic.approved, :count
    assert_respond_to Topic.approved, :length
  end

  def test_scopes_with_options_limit_finds_to_those_matching_the_criteria_specified
    assert_not_empty Topic.all.merge!(where: { approved: true }).to_a

    assert_equal Topic.all.merge!(where: { approved: true }).to_a, Topic.approved
    assert_equal Topic.where(approved: true).count, Topic.approved.count
  end

  def test_scopes_with_string_name_can_be_composed
    # NOTE that scopes defined with a string as a name worked on their own
    # but when called on another scope the other scope was completely replaced
    assert_equal Topic.replied.approved, Topic.replied.approved_as_string
  end

  def test_scopes_are_composable
    assert_equal((approved = Topic.all.merge!(where: { approved: true }).to_a), Topic.approved)
    assert_equal((replied = Topic.all.merge!(where: "replies_count > 0").to_a), Topic.replied)
    assert !(approved == replied)
    assert_not_empty (approved & replied)

    assert_equal approved & replied, Topic.approved.replied
  end

  def test_procedural_scopes
    topics_written_before_the_third = Topic.where("written_on < ?", topics(:third).written_on)
    topics_written_before_the_second = Topic.where("written_on < ?", topics(:second).written_on)
    assert_not_equal topics_written_before_the_second, topics_written_before_the_third

    assert_equal topics_written_before_the_third, Topic.written_before(topics(:third).written_on)
    assert_equal topics_written_before_the_second, Topic.written_before(topics(:second).written_on)
  end

  def test_procedural_scopes_returning_nil
    all_topics = Topic.all

    assert_equal all_topics, Topic.written_before(nil)
  end

  def test_scope_with_object
    objects = Topic.with_object
    assert_operator objects.length, :>, 0
    assert objects.all?(&:approved?), "all objects should be approved"
  end

  def test_has_many_associations_have_access_to_scopes
    assert_not_equal Post.containing_the_letter_a, authors(:david).posts
    assert_not_empty Post.containing_the_letter_a

    expected = authors(:david).posts & Post.containing_the_letter_a
    assert_equal expected.sort_by(&:id), authors(:david).posts.containing_the_letter_a.sort_by(&:id)
  end

  def test_scope_with_STI
    assert_equal 3, Post.containing_the_letter_a.count
    assert_equal 1, SpecialPost.containing_the_letter_a.count
  end

  def test_has_many_through_associations_have_access_to_scopes
    assert_not_equal Comment.containing_the_letter_e, authors(:david).comments
    assert_not_empty Comment.containing_the_letter_e

    expected = authors(:david).comments & Comment.containing_the_letter_e
    assert_equal expected.sort_by(&:id), authors(:david).comments.containing_the_letter_e.sort_by(&:id)
  end

  def test_scopes_honor_current_scopes_from_when_defined
    assert_not_empty Post.ranked_by_comments.limit_by(5)
    assert_not_empty authors(:david).posts.ranked_by_comments.limit_by(5)
    assert_not_equal Post.ranked_by_comments.limit_by(5), authors(:david).posts.ranked_by_comments.limit_by(5)
    assert_not_equal Post.top(5), authors(:david).posts.top(5)
    # Oracle sometimes sorts differently if WHERE condition is changed
    assert_equal authors(:david).posts.ranked_by_comments.limit_by(5).to_a.sort_by(&:id), authors(:david).posts.top(5).to_a.sort_by(&:id)
    assert_equal Post.ranked_by_comments.limit_by(5), Post.top(5)
  end

  def test_scopes_body_is_a_callable
    e = assert_raises ArgumentError do
      Class.new(Post).class_eval { scope :containing_the_letter_z, where("body LIKE '%z%'") }
    end
    assert_equal "The scope body needs to be callable.", e.message
  end

  def test_scopes_name_is_relation_method
    conflicts = [
      :records,
      :to_ary,
      :to_sql,
      :explain
    ]

    conflicts.each do |name|
      e = assert_raises ArgumentError do
        Class.new(Post).class_eval { scope name, -> { where(approved: true) } }
      end
      assert_match(/You tried to define a scope named \"#{name}\" on the model/, e.message)
    end
  end

  def test_active_records_have_scope_named__all__
    assert_not_empty Topic.all

    assert_equal Topic.all.to_a, Topic.base
  end

  def test_active_records_have_scope_named__scoped__
    scope = Topic.where("content LIKE '%Have%'")
    assert_not_empty scope

    assert_equal scope, Topic.all.merge!(where: "content LIKE '%Have%'")
  end

  def test_first_and_last_should_allow_integers_for_limit
    assert_equal Topic.base.first(2), Topic.base.order("id").to_a.first(2)
    assert_equal Topic.base.last(2), Topic.base.order("id").to_a.last(2)
  end

  def test_first_and_last_should_not_use_query_when_results_are_loaded
    topics = Topic.base
    topics.load # force load
    assert_no_queries do
      topics.first
      topics.last
    end
  end

  def test_empty_should_not_load_results
    topics = Topic.base
    assert_queries(2) do
      topics.empty?  # use count query
      topics.load    # force load
      topics.empty?  # use loaded (no query)
    end
  end

  def test_any_should_not_load_results
    topics = Topic.base
    assert_queries(2) do
      topics.any?    # use count query
      topics.load    # force load
      topics.any?    # use loaded (no query)
    end
  end

  def test_any_should_call_proxy_found_if_using_a_block
    topics = Topic.base
    assert_queries(1) do
      assert_not_called(topics, :empty?) do
        topics.any? { true }
      end
    end
  end

  def test_any_should_not_fire_query_if_scope_loaded
    topics = Topic.base
    topics.load # force load
    assert_no_queries { assert topics.any? }
  end

  def test_model_class_should_respond_to_any
    assert_predicate Topic, :any?
    Topic.delete_all
    assert_not_predicate Topic, :any?
  end

  def test_many_should_not_load_results
    topics = Topic.base
    assert_queries(2) do
      topics.many?   # use count query
      topics.load    # force load
      topics.many?   # use loaded (no query)
    end
  end

  def test_many_should_call_proxy_found_if_using_a_block
    topics = Topic.base
    assert_queries(1) do
      assert_not_called(topics, :size) do
        topics.many? { true }
      end
    end
  end

  def test_many_should_not_fire_query_if_scope_loaded
    topics = Topic.base
    topics.load # force load
    assert_no_queries { assert topics.many? }
  end

  def test_many_should_return_false_if_none_or_one
    topics = Topic.base.where(id: 0)
    assert_not_predicate topics, :many?
    topics = Topic.base.where(id: 1)
    assert_not_predicate topics, :many?
  end

  def test_many_should_return_true_if_more_than_one
    assert_predicate Topic.base, :many?
  end

  def test_model_class_should_respond_to_many
    Topic.delete_all
    assert_not_predicate Topic, :many?
    Topic.create!
    assert_not_predicate Topic, :many?
    Topic.create!
    assert_predicate Topic, :many?
  end

  def test_should_build_on_top_of_scope
    topic = Topic.approved.build({})
    assert topic.approved
  end

  def test_should_build_new_on_top_of_scope
    topic = Topic.approved.new
    assert topic.approved
  end

  def test_should_create_on_top_of_scope
    topic = Topic.approved.create({})
    assert topic.approved
  end

  def test_should_create_with_bang_on_top_of_scope
    topic = Topic.approved.create!({})
    assert topic.approved
  end

  def test_should_build_on_top_of_chained_scopes
    topic = Topic.approved.by_lifo.build({})
    assert topic.approved
    assert_equal "lifo", topic.author_name
  end

  def test_deprecated_delegating_private_method
    assert_deprecated do
      scope = Topic.all.by_private_lifo
      assert_not scope.instance_variable_get(:@delegate_to_klass)
    end
  end

  def test_reserved_scope_names
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"

      scope :approved, -> { where(approved: true) }

      class << self
        public
          def pub; end

        private
          def pri; end

        protected
          def pro; end
      end
    end

    subklass = Class.new(klass)

    conflicts = [
      :create,        # public class method on AR::Base
      :relation,      # private class method on AR::Base
      :new,           # redefined class method on AR::Base
      :all,           # a default scope
      :public,        # some important methods on Module and Class
      :protected,
      :private,
      :name,
      :parent,
      :superclass
    ]

    non_conflicts = [
      :find_by_title, # dynamic finder method
      :approved,      # existing scope
      :pub,           # existing public class method
      :pri,           # existing private class method
      :pro,           # existing protected class method
      :open,          # a ::Kernel method
    ]

    conflicts.each do |name|
      e = assert_raises(ArgumentError, "scope `#{name}` should not be allowed") do
        klass.class_eval { scope name, -> { where(approved: true) } }
      end
      assert_match(/You tried to define a scope named \"#{name}\" on the model/, e.message)

      e = assert_raises(ArgumentError, "scope `#{name}` should not be allowed") do
        subklass.class_eval { scope name, -> { where(approved: true) } }
      end
      assert_match(/You tried to define a scope named \"#{name}\" on the model/, e.message)
    end

    non_conflicts.each do |name|
      assert_nothing_raised do
        silence_warnings do
          klass.class_eval { scope name, -> { where(approved: true) } }
        end
      end

      assert_nothing_raised do
        subklass.class_eval { scope name, -> { where(approved: true) } }
      end
    end
  end

  # Method delegation for scope names which look like /\A[a-zA-Z_]\w*[!?]?\z/
  # has been done by evaluating a string with a plain def statement. For scope
  # names which contain spaces this approach doesn't work.
  def test_spaces_in_scope_names
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "topics"
      scope :"title containing space", -> { where("title LIKE '% %'") }
      scope :approved, -> { where(approved: true) }
    end
    assert_equal klass.send(:"title containing space"), klass.where("title LIKE '% %'")
    assert_equal klass.approved.send(:"title containing space"), klass.approved.where("title LIKE '% %'")
  end

  def test_find_all_should_behave_like_select
    assert_equal Topic.base.to_a.select(&:approved), Topic.base.to_a.find_all(&:approved)
  end

  def test_rand_should_select_a_random_object_from_proxy
    assert_kind_of Topic, Topic.approved.sample
  end

  def test_should_use_where_in_query_for_scope
    assert_equal Developer.where(name: "Jamis").to_set, Developer.where(id: Developer.jamises).to_set
  end

  def test_size_should_use_count_when_results_are_not_loaded
    topics = Topic.base
    assert_queries(1) do
      assert_sql(/COUNT/i) { topics.size }
    end
  end

  def test_size_should_use_length_when_results_are_loaded
    topics = Topic.base
    topics.load # force load
    assert_no_queries do
      topics.size # use loaded (no query)
    end
  end

  def test_should_not_duplicates_where_values
    relation = Topic.where("1=1")
    assert_equal relation.where_clause, relation.scope_with_lambda.where_clause
  end

  def test_chaining_with_duplicate_joins
    join = "INNER JOIN comments ON comments.post_id = posts.id"
    post = Post.find(1)
    assert_equal post.comments.size, Post.joins(join).joins(join).where("posts.id = #{post.id}").size
  end

  def test_chaining_applies_last_conditions_when_creating
    post = Topic.rejected.new
    assert_not_predicate post, :approved?

    post = Topic.rejected.approved.new
    assert_predicate post, :approved?

    post = Topic.approved.rejected.new
    assert_not_predicate post, :approved?

    post = Topic.approved.rejected.approved.new
    assert_predicate post, :approved?
  end

  def test_chaining_combines_conditions_when_searching
    # Normal hash conditions
    assert_equal Topic.where(approved: false).where(approved: true).to_a, Topic.rejected.approved.to_a
    assert_equal Topic.where(approved: true).where(approved: false).to_a, Topic.approved.rejected.to_a

    # Nested hash conditions with same keys
    assert_equal [], Post.with_special_comments.with_very_special_comments.to_a

    # Nested hash conditions with different keys
    assert_equal [posts(:sti_comments)], Post.with_special_comments.with_post(4).to_a.uniq
  end

  def test_scopes_batch_finders
    assert_equal 4, Topic.approved.count

    assert_queries(5) do
      Topic.approved.find_each(batch_size: 1) { |t| assert t.approved? }
    end

    assert_queries(3) do
      Topic.approved.find_in_batches(batch_size: 2) do |group|
        group.each { |t| assert t.approved? }
      end
    end
  end

  def test_table_names_for_chaining_scopes_with_and_without_table_name_included
    assert_nothing_raised do
      Comment.for_first_post.for_first_author.to_a
    end
  end

  def test_scopes_with_reserved_names
    class << Topic
      def public_method; end
      public :public_method

      def protected_method; end
      protected :protected_method

      def private_method; end
      private :private_method
    end

    [:public_method, :protected_method, :private_method].each do |reserved_method|
      assert Topic.respond_to?(reserved_method, true)
      ActiveRecord::Base.logger.expects(:warn)
      silence_warnings { Topic.scope(reserved_method, -> {}) }
    end
  end

  def test_scopes_on_relations
    # Topic.replied
    approved_topics = Topic.all.approved.order("id DESC")
    assert_equal topics(:fifth), approved_topics.first

    replied_approved_topics = approved_topics.replied
    assert_equal topics(:third), replied_approved_topics.first
  end

  def test_index_on_scope
    approved = Topic.approved.order("id ASC")
    assert_equal topics(:second), approved[0]
    assert_predicate approved, :loaded?
  end

  def test_nested_scopes_queries_size
    assert_queries(1) do
      Topic.approved.by_lifo.replied.written_before(Time.now).to_a
    end
  end

  # Note: these next two are kinda odd because they are essentially just testing that the
  # query cache works as it should, but they are here for legacy reasons as they was previously
  # a separate cache on association proxies, and these show that that is not necessary.
  def test_scopes_are_cached_on_associations
    post = posts(:welcome)

    Post.cache do
      assert_queries(1) { post.comments.containing_the_letter_e.to_a }
      assert_no_queries { post.comments.containing_the_letter_e.to_a }
    end
  end

  def test_scopes_with_arguments_are_cached_on_associations
    post = posts(:welcome)

    Post.cache do
      one = assert_queries(1) { post.comments.limit_by(1).to_a }
      assert_equal 1, one.size

      two = assert_queries(1) { post.comments.limit_by(2).to_a }
      assert_equal 2, two.size

      assert_no_queries { post.comments.limit_by(1).to_a }
      assert_no_queries { post.comments.limit_by(2).to_a }
    end
  end

  def test_scopes_to_get_newest
    post = posts(:welcome)
    old_last_comment = post.comments.newest
    new_comment = post.comments.create(body: "My new comment")
    assert_equal new_comment, post.comments.newest
    assert_not_equal old_last_comment, post.comments.newest
  end

  def test_scopes_are_reset_on_association_reload
    post = posts(:welcome)

    [:destroy_all, :reset, :delete_all].each do |method|
      before = post.comments.containing_the_letter_e
      post.association(:comments).send(method)
      assert before.object_id != post.comments.containing_the_letter_e.object_id, "CollectionAssociation##{method} should reset the named scopes cache"
    end
  end

  def test_scoped_are_lazy_loaded_if_table_still_does_not_exist
    assert_nothing_raised do
      require "models/without_table"
    end
  end

  def test_eager_default_scope_relations_are_remove
    klass = Class.new(ActiveRecord::Base)
    klass.table_name = "posts"

    assert_raises(ArgumentError) do
      klass.send(:default_scope, klass.where(id: posts(:welcome).id))
    end
  end

  def test_subclass_merges_scopes_properly
    assert_equal 1, SpecialComment.where(body: "go crazy").created.count
  end

  def test_model_class_should_respond_to_extending
    assert_raises OopsError do
      Comment.unscoped.oops_comments.destroy_all
    end
  end

  def test_model_class_should_respond_to_none
    assert_not_predicate Topic, :none?
    Topic.delete_all
    assert_predicate Topic, :none?
  end

  def test_model_class_should_respond_to_one
    assert_not_predicate Topic, :one?
    Topic.delete_all
    assert_not_predicate Topic, :one?
    Topic.create!
    assert_predicate Topic, :one?
  end
end
