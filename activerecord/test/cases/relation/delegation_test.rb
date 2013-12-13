require 'cases/helper'
require 'models/post'
require 'models/comment'

module ActiveRecord
  class DelegationTest < ActiveRecord::TestCase
    fixtures :posts

    def call_method(target, method)
      method_arity = target.to_a.method(method).arity

      if method_arity.zero?
        target.public_send(method)
      elsif method_arity < 0
        if method == :shuffle!
          target.public_send(method)
        else
          target.public_send(method, 1)
        end
       elsif method_arity == 1
        target.public_send(method, 1)
      else
        raise NotImplementedError
      end
    end
  end

  module DelegationWhitelistBlacklistTests
    ActiveRecord::Delegation::ARRAY_DELEGATES.each do |method|
      define_method "test_delegates_#{method}_to_Array" do
        assert_respond_to target, method
      end
    end

    [:compact!, :flatten!, :reject!, :reverse!, :rotate!,
     :shuffle!, :slice!, :sort!, :sort_by!, :delete_if,
     :keep_if, :pop, :shift, :delete_at, :compact].each do |method|
      define_method "test_#{method}_is_not_delegated_to_Array" do
        assert_raises(NoMethodError) { call_method(target, method) }
      end
    end
  end

  class DelegationAssociationTest < DelegationTest
    include DelegationWhitelistBlacklistTests

    def target
      Post.first.comments
    end
  end

  class DelegationRelationTest < DelegationTest
    include DelegationWhitelistBlacklistTests

    fixtures :comments

    def target
      Comment.all
    end
  end
end
