# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "active_support/core_ext/symbol/starts_ends_with"

module ActiveRecord
  module DelegationTests
    ARRAY_DELEGATES = [
      :+, :-, :|, :&, :[], :shuffle,
      :all?, :collect, :compact, :detect, :each, :each_cons, :each_with_index,
      :exclude?, :find_all, :flat_map, :group_by, :include?, :length,
      :map, :none?, :one?, :partition, :reject, :reverse, :rotate,
      :sample, :second, :sort, :sort_by, :slice, :third, :index, :rindex,
      :to_ary, :to_set, :to_xml, :to_yaml, :join,
      :in_groups, :in_groups_of, :to_sentence, :to_formatted_s, :as_json
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

  class QueryingMethodsDelegationTest < ActiveRecord::TestCase
    QUERYING_METHODS =
      ActiveRecord::Batches.public_instance_methods(false) +
      ActiveRecord::Calculations.public_instance_methods(false) +
      ActiveRecord::FinderMethods.public_instance_methods(false) - [:include?, :member?, :raise_record_not_found_exception!] +
      ActiveRecord::SpawnMethods.public_instance_methods(false) - [:spawn, :merge!] +
      ActiveRecord::QueryMethods.public_instance_methods(false).reject { |method|
        method.end_with?("=", "!", "value", "values", "clause")
      } - [:reverse_order, :arel, :extensions, :construct_join_dependency] + [
        :any?, :many?, :none?, :one?,
        :first_or_create, :first_or_create!, :first_or_initialize,
        :find_or_create_by, :find_or_create_by!, :find_or_initialize_by,
        :create_or_find_by, :create_or_find_by!,
        :destroy_all, :delete_all, :update_all, :touch_all, :delete_by, :destroy_by
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
end
