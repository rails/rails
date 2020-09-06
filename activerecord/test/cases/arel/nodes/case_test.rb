# frozen_string_literal: true

require_relative '../helper'

module Arel
  module Nodes
    class NodesTest < Arel::Spec
      describe 'Case' do
        describe '#initialize' do
          it 'sets case expression from first argument' do
            node = Case.new 'foo'

            assert_equal 'foo', node.case
          end

          it 'sets default case from second argument' do
            node = Case.new nil, 'bar'

            assert_equal 'bar', node.default
          end
        end

        describe '#clone' do
          it 'clones case, conditions and default' do
            foo = Nodes.build_quoted 'foo'

            node = Case.new
            node.case = foo
            node.conditions = [When.new(foo, foo)]
            node.default = foo

            dolly = node.clone

            assert_equal dolly.case, node.case
            assert_not_same dolly.case, node.case

            assert_equal dolly.conditions, node.conditions
            assert_not_same dolly.conditions, node.conditions

            assert_equal dolly.default, node.default
            assert_not_same dolly.default, node.default
          end
        end

        describe 'equality' do
          it 'is equal with equal ivars' do
            foo = Nodes.build_quoted 'foo'
            one = Nodes.build_quoted 1
            zero = Nodes.build_quoted 0

            case1 = Case.new foo
            case1.conditions = [When.new(foo, one)]
            case1.default = Else.new zero

            case2 = Case.new foo
            case2.conditions = [When.new(foo, one)]
            case2.default = Else.new zero

            array = [case1, case2]

            assert_equal 1, array.uniq.size
          end

          it 'is not equal with different ivars' do
            foo = Nodes.build_quoted 'foo'
            bar = Nodes.build_quoted 'bar'
            one = Nodes.build_quoted 1
            zero = Nodes.build_quoted 0

            case1 = Case.new foo
            case1.conditions = [When.new(foo, one)]
            case1.default = Else.new zero

            case2 = Case.new foo
            case2.conditions = [When.new(bar, one)]
            case2.default = Else.new zero

            array = [case1, case2]

            assert_equal 2, array.uniq.size
          end
        end

        describe '#as' do
          it 'allows aliasing' do
            node = Case.new 'foo'
            as = node.as('bar')

            assert_equal node, as.left
            assert_kind_of Arel::Nodes::SqlLiteral, as.right
          end
        end
      end
    end
  end
end
