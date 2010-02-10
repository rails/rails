require 'spec_helper'

module Arel
  module Predicates
    describe Binary do
      class ConcreteBinary < Binary
        def predicate_sql
          "<=>"
        end
      end

      before do
        @relation = Arel::Table.new(:users)
        @attribute1 = @relation[:id]
        @attribute2 = @relation[:name]
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

              adapter_is :postgresql do
                sql.should be_like(%Q{("users"."id" <=> 1 OR "users"."name" <=> E'name')})
              end

              adapter_is :sqlite3 do
                sql.should be_like(%Q{("users"."id" <=> 1 OR "users"."name" <=> 'name')})
              end

              adapter_is :oracle do
                sql.should be_like(%Q{("USERS"."ID" <=> 1 OR "USERS"."NAME" <=> 'name')})
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

              adapter_is :sqlite3 do
                sql.should be_like(%Q{("users"."id" <=> 1 AND "users"."name" <=> 'name')})
              end

              adapter_is :postgresql do
                sql.should be_like(%Q{("users"."id" <=> 1 AND "users"."name" <=> E'name')})
              end

              adapter_is :oracle do
                sql.should be_like(%Q{("USERS"."ID" <=> 1 AND "USERS"."NAME" <=> 'name')})
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

            adapter_is :oracle do
              sql.should be_like(%Q{"USERS"."ID" <=> "USERS"."NAME"})
            end

            adapter_is_not :mysql, :oracle do
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

              adapter_is :oracle do
                sql.should be_like(%Q{"USERS"."ID" <=> 1})
              end

              adapter_is_not :mysql, :oracle do
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

              adapter_is :sqlite3 do
                sql.should be_like(%Q{"users"."name" <=> '1-asdf'})
              end

              adapter_is :postgresql do
                sql.should be_like(%Q{"users"."name" <=> E'1-asdf'})
              end

              adapter_is :oracle do
                sql.should be_like(%Q{"USERS"."NAME" <=> '1-asdf'})
              end
            end
          end
        end
      end
    end
  end
end
