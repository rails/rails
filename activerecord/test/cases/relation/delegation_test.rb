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

  class DelegationAssociationTest < DelegationTest
    def target
      Post.first.comments
    end

    [:&, :+, :[], :all?, :collect, :detect, :each, :each_cons,
     :each_with_index, :flat_map, :group_by, :include?, :length,
     :map, :none?, :one?, :reverse, :sample, :second, :sort, :sort_by,
     :to_ary, :to_set, :to_xml, :to_yaml].each do |method|
      test "association delegates #{method} to Array" do
        assert_respond_to target, method
      end
    end

    [:compact!, :flatten!, :reject!, :reverse!, :rotate!,
     :shuffle!, :slice!, :sort!, :sort_by!, :delete_if,
     :keep_if, :pop, :shift, :delete_at, :compact].each do |method|
      test "#{method} is not delegated to Array" do
        assert_raises(NoMethodError) { call_method(target, method) }
      end
    end
  end

  class DelegationRelationTest < DelegationTest
    fixtures :comments

    def target
      Comment.all
    end

    [:&, :+, :[], :all?, :collect, :detect, :each, :each_cons,
     :each_with_index, :flat_map, :group_by, :include?, :length,
     :map, :none?, :one?, :reverse, :sample, :second, :sort, :sort_by,
     :to_ary, :to_set, :to_xml, :to_yaml].each do |method|
      test "relation delegates #{method} to Array" do
        assert_respond_to target, method
      end
    end

    [:compact!, :flatten!, :reject!, :reverse!, :rotate!,
     :shuffle!, :slice!, :sort!, :sort_by!, :delete_if,
     :keep_if, :pop, :shift, :delete_at, :compact].each do |method|
      test "#{method} is not delegated to Array" do
        assert_raises(NoMethodError) { call_method(target, method) }
      end
    end
  end
end
