require File.join(File.dirname(__FILE__), '..', '..', '..', '..', '..', 'spec_helper')

module Arel
  describe Binary do
    before do
      @relation = Table.new(:users)
      @attribute1 = @relation[:id]
      @attribute2 = @relation[:name]
      class ConcreteBinary < Binary
        def predicate_sql
          "<=>"
        end
      end
    end

    describe "with compound predicates" do
      before do
        @operand1 = ConcreteBinary.new(@attribute1, 1)
        @operand2 = ConcreteBinary.new(@attribute2, "name")
      end

      describe Or do
        describe "#to_sql" do
          it "manufactures sql with an OR operation" do
            sql = Or.new(@operand1, @operand2).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{(`users`.`id` <=> 1 OR `users`.`name` <=> 'name')})
            end

            adapter_is_not :mysql do
              sql.should be_like(%Q{("users"."id" <=> 1 OR "users"."name" <=> 'name')})
            end
          end
        end
      end

      describe And do
        describe "#to_sql" do
          it "manufactures sql with an AND operation" do
            sql = And.new(@operand1, @operand2).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{(`users`.`id` <=> 1 AND `users`.`name` <=> 'name')})
            end

            adapter_is_not :mysql do
              sql.should be_like(%Q{("users"."id" <=> 1 AND "users"."name" <=> 'name')})
            end
          end
        end
      end
    end

    describe '#to_sql' do
      describe 'when relating two attributes' do
        it 'manufactures sql with a binary operation' do
          sql = ConcreteBinary.new(@attribute1, @attribute2).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{`users`.`id` <=> `users`.`name`})
          end

          adapter_is_not :mysql do
            sql.should be_like(%Q{"users"."id" <=> "users"."name"})
          end
        end
      end

      describe 'when relating an attribute and a value' do
        before do
          @value = "1-asdf"
        end

        describe 'when relating to an integer attribute' do
          it 'formats values as integers' do
            sql = ConcreteBinary.new(@attribute1, @value).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{`users`.`id` <=> 1})
            end

            adapter_is_not :mysql do
              sql.should be_like(%Q{"users"."id" <=> 1})
            end
          end
        end

        describe 'when relating to a string attribute' do
          it 'formats values as strings' do
            sql = ConcreteBinary.new(@attribute2, @value).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{`users`.`name` <=> '1-asdf'})
            end

            adapter_is_not :mysql do
              sql.should be_like(%Q{"users"."name" <=> '1-asdf'})
            end
          end
        end
      end
    end

    describe '#bind' do
      before do
        @another_relation = @relation.alias
      end

      describe 'when both operands are attributes' do
        it "manufactures an expression with the attributes bound to the relation" do
          ConcreteBinary.new(@attribute1, @attribute2).bind(@another_relation). \
            should == ConcreteBinary.new(@another_relation[@attribute1], @another_relation[@attribute2])
        end
      end

      describe 'when an operand is a value' do
        it "manufactures an expression with unmodified values" do
          ConcreteBinary.new(@attribute1, "asdf").bind(@another_relation). \
            should == ConcreteBinary.new(@attribute1.find_correlate_in(@another_relation), "asdf".find_correlate_in(@another_relation))
        end
      end
    end
  end
end