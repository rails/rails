require "cases/helper"
require "models/post"
require "models/comment"

module ActiveRecord
  module DelegationWhitelistTests
    ARRAY_DELEGATES = [
      :+, :-, :|, :&, :[], :shuffle,
      :all?, :collect, :compact, :detect, :each, :each_cons, :each_with_index,
      :exclude?, :find_all, :flat_map, :group_by, :include?, :length,
      :map, :none?, :one?, :partition, :reject, :reverse,
      :sample, :second, :sort, :sort_by, :third,
      :to_ary, :to_set, :to_xml, :to_yaml, :join,
      :in_groups, :in_groups_of, :to_sentence, :to_formatted_s, :as_json
    ]

    ARRAY_DELEGATES.each do |method|
      define_method "test_delegates_#{method}_to_Array" do
        assert_respond_to target, method
      end
    end
  end

  class DelegationAssociationTest < ActiveRecord::TestCase
    include DelegationWhitelistTests

    fixtures :posts

    def target
      Post.first.comments
    end
  end

  class DelegationRelationTest < ActiveRecord::TestCase
    include DelegationWhitelistTests

    fixtures :comments

    def target
      Comment.all
    end
  end
end
