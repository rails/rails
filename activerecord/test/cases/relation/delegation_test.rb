require 'cases/helper'
require 'models/post'
require 'models/comment'

module ActiveRecord
  class DelegationTest < ActiveRecord::TestCase
    fixtures :posts

    def assert_responds(target, method)
      assert target.respond_to?(method)
      assert_nothing_raised do
        case target.to_a.method(method).arity
        when 0
          target.send(method)
        when -1
          if method == :shuffle!
            target.send(method)
          else
            target.send(method, 1)
          end
        else
          raise NotImplementedError
        end
      end
    end
  end

  class DelegationAssociationTest < DelegationTest
    def target
      Post.first.comments
    end

    [:map, :collect].each do |method|
      test "##{method} is delgated" do
        assert_responds(target, method)
        assert_equal(target.pluck(:body), target.send(method) {|post| post.body })
      end

      test "##{method}! is not delgated" do
        assert_deprecated do
          assert_responds(target, "#{method}!")
        end
      end
    end

    [:compact!, :flatten!, :reject!, :reverse!, :rotate!,
      :shuffle!, :slice!, :sort!, :sort_by!].each do |method|
      test "##{method} delegation is deprecated" do
        assert_deprecated do
          assert_responds(target, method)
        end
      end
    end

    [:select!, :uniq!].each do |method|
      test "##{method} is implemented" do
        assert_responds(target, method)
      end
    end
  end

  class DelegationRelationTest < DelegationTest
    def target
      Comment.where.not(body: nil)
    end

    [:map, :collect].each do |method|
      test "##{method} is delgated" do
        assert_responds(target, method)
        assert_equal(target.pluck(:body), target.send(method) {|post| post.body })
      end

      test "##{method}! is not delgated" do
        assert_deprecated do
          assert_responds(target, "#{method}!")
        end
      end
    end

    [:compact!, :flatten!, :reject!, :reverse!, :rotate!,
      :shuffle!, :slice!, :sort!, :sort_by!].each do |method|
      test "##{method} delegation is deprecated" do
        assert_deprecated do
          assert_responds(target, method)
        end
      end
    end

    [:select!, :uniq!].each do |method|
      test "##{method} is triggers an immutable error" do
        assert_raises ActiveRecord::ImmutableRelation do
          assert_responds(target, method)
        end
      end
    end
  end
end
