# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

module ActiveRecord
  module DelegationWhitelistTests
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
  end

  module DeprecatedArelDelegationTests
    AREL_METHODS = [
      :with, :orders, :froms, :project, :projections, :taken, :constraints, :exists, :locked, :where_sql,
      :ast, :source, :join_sources, :to_dot, :create_insert, :create_true, :create_false
    ]

    def test_deprecate_arel_delegation
      AREL_METHODS.each do |method|
        assert_deprecated { target.public_send(method) }
        assert_deprecated { target.public_send(method) }
      end
    end
  end

  class DelegationAssociationTest < ActiveRecord::TestCase
    include DelegationWhitelistTests
    include DeprecatedArelDelegationTests

    def target
      Post.new.comments
    end
  end

  class DelegationRelationTest < ActiveRecord::TestCase
    include DelegationWhitelistTests
    include DeprecatedArelDelegationTests

    def target
      Comment.all
    end
  end
end
