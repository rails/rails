require 'test_helper'

module Arel
  module Nodes
    describe 'equality' do
      # FIXME: backwards compat
      describe 'backwards compat' do
        describe 'operator' do
          it 'returns :==' do
            attr = Table.new(:users)[:id]
            left  = attr.eq(10)
            check left.operator.must_equal :==
          end
        end

        describe 'operand1' do
          it "should equal left" do
            attr = Table.new(:users)[:id]
            left  = attr.eq(10)
            check left.left.must_equal left.operand1
          end
        end

        describe 'operand2' do
          it "should equal right" do
            attr = Table.new(:users)[:id]
            left  = attr.eq(10)
            check left.right.must_equal left.operand2
          end
        end

        describe 'to_sql' do
          it 'takes an engine' do
            engine = FakeRecord::Base.new
            engine.connection.extend Module.new {
              attr_accessor :quote_count
              def quote(*args) @quote_count += 1; super; end
              def quote_column_name(*args) @quote_count += 1; super; end
              def quote_table_name(*args) @quote_count += 1; super; end
            }
            engine.connection.quote_count = 0

            attr = Table.new(:users)[:id]
            test = attr.eq(10)
            test.to_sql engine
            check engine.connection.quote_count.must_equal 2
          end
        end
      end

      describe 'or' do
        it 'makes an OR node' do
          attr = Table.new(:users)[:id]
          left  = attr.eq(10)
          right = attr.eq(11)
          node  = left.or right
          check node.expr.left.must_equal left
          check node.expr.right.must_equal right
        end
      end

      describe 'and' do
        it 'makes and AND node' do
          attr = Table.new(:users)[:id]
          left  = attr.eq(10)
          right = attr.eq(11)
          node  = left.and right
          check node.left.must_equal left
          check node.right.must_equal right
        end
      end
    end
  end
end
