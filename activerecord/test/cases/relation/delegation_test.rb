# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "models/project"
require "models/developer"

module ActiveRecord
  module DelegationTests
    ARRAY_DELEGATES = [
      :+, :-, :|, :&, :[], :shuffle,
      :all?, :collect, :compact, :detect, :each, :each_cons, :each_with_index,
      :exclude?, :find_all, :flat_map, :group_by, :include?, :length,
      :map, :none?, :one?, :partition, :reject, :reverse, :rotate,
      :sample, :second, :sort, :sort_by, :slice, :third, :index, :rindex,
      :to_ary, :to_set, :to_xml, :to_yaml, :join,
      :in_groups, :in_groups_of, :to_sentence, :to_formatted_s, :to_fs, :as_json,
      :intersect?
    ]

    ARRAY_DELEGATES.each do |method|
      define_method "test_delegates_#{method}_to_Array" do
        assert_respond_to target, method
      end
    end

    def test_not_respond_to_arel_method
      assert_not_respond_to target, :exists
    end
  end

  class DelegationAssociationTest < ActiveRecord::TestCase
    include DelegationTests

    def target
      Post.new.comments
    end
  end

  class DelegationRelationTest < ActiveRecord::TestCase
    include DelegationTests

    def target
      Comment.all
    end
  end

  class DelegationRecordsTest < ActiveRecord::TestCase
    include DelegationTests

    def target
      Comment.all.records
    end
  end

  class QueryingMethodsDelegationTest < ActiveRecord::TestCase
    QUERYING_METHODS =
      ActiveRecord::Batches.public_instance_methods(false) +
      ActiveRecord::Calculations.public_instance_methods(false) +
      ActiveRecord::FinderMethods.public_instance_methods(false) - [:include?, :member?, :raise_record_not_found_exception!] +
      ActiveRecord::SpawnMethods.public_instance_methods(false) - [:spawn, :merge!] +
      ActiveRecord::QueryMethods.public_instance_methods(false).reject { |method|
        method.end_with?("=", "!", "?", "value", "values", "clause")
      } - [:all, :reverse_order, :arel, :extensions, :construct_join_dependency] + [
        :any?, :many?, :none?, :one?,
        :first_or_create, :first_or_create!, :first_or_initialize,
        :find_or_create_by, :find_or_create_by!, :find_or_initialize_by,
        :create_or_find_by, :create_or_find_by!,
        :destroy, :destroy_all, :delete, :delete_all, :update_all, :touch_all, :delete_by, :destroy_by,
        :insert, :insert_all, :insert!, :insert_all!, :upsert, :upsert_all,
      ]

    def test_delegate_querying_methods
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "posts"
      end

      assert_equal QUERYING_METHODS.sort, ActiveRecord::Querying::QUERYING_METHODS.sort

      QUERYING_METHODS.each do |method|
        assert_respond_to klass.all, method
        assert_respond_to klass, method
      end
    end
  end

  class DelegationCachingTest < ActiveRecord::TestCase
    fixtures :projects, :developers

    test "delegation doesn't override methods defined in other relation subclasses" do
      # precondition, some methods are available on ActiveRecord::Relation subclasses
      # but not ActiveRecord::Relation itself. Here `target` is just an example.
      assert_equal false, ActiveRecord::Relation.method_defined?(:target)
      assert_equal true, ActiveRecord::Associations::CollectionProxy.method_defined?(:target)

      project = projects(:active_record)
      original_owner = project.developers_with_callbacks.method(:target).owner
      assert_equal :__target__, Developer.all.target
      assert_equal original_owner, project.developers_with_callbacks.method(:target).owner
    end
  end
end
