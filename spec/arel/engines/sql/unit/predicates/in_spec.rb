require 'spec_helper'

module Arel
  module Predicates
    describe In do
      before do
        @relation = Arel::Table.new(:users)
        @attribute = @relation[:id]
      end

      describe '#to_sql' do
        describe 'when relating to an array' do
          describe 'when the array\'s elements are the same type as the attribute' do
            before do
              @array = [1, 2, 3]
            end

            it 'manufactures sql with a comma separated list' do
              sql = In.new(@attribute, @array).to_sql

              adapter_is :mysql do
                sql.should be_like(%Q{`users`.`id` IN (1, 2, 3)})
              end

              adapter_is_not :mysql do
                sql.should be_like(%Q{"users"."id" IN (1, 2, 3)})
              end
            end
          end

          describe 'when the array\'s elements are not same type as the attribute' do
            before do
              @array = ['1-asdf', 2, 3]
            end

            it 'formats values in the array as the type of the attribute' do
              sql = In.new(@attribute, @array).to_sql

              adapter_is :mysql do
                sql.should be_like(%Q{`users`.`id` IN (1, 2, 3)})
              end

              adapter_is_not :mysql do
                sql.should be_like(%Q{"users"."id" IN (1, 2, 3)})
              end
            end
          end

          describe 'when the array is empty' do
            before do
              @array = []
            end

            it 'manufactures sql with a comma separated list' do
              sql = In.new(@attribute, @array).to_sql

              adapter_is :mysql do
                sql.should be_like(%Q{`users`.`id` IN (NULL)})
              end

              adapter_is_not :mysql do
                sql.should be_like(%Q{"users"."id" IN (NULL)})
              end
            end
          end

        end

        describe 'when relating to a range' do
          before do
            @range = 1..2
          end

          it 'manufactures sql with a between' do
            sql = In.new(@attribute, @range).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{`users`.`id` BETWEEN 1 AND 2})
            end

            adapter_is_not :mysql do
              sql.should be_like(%Q{"users"."id" BETWEEN 1 AND 2})
            end
          end
        end

        describe 'when relating to a relation' do
          it 'manufactures sql with a subselect' do
            sql = In.new(@attribute, @relation).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                `users`.`id` IN (SELECT `users`.`id`, `users`.`name` FROM `users`)
              })
            end

            adapter_is_not :mysql do
              sql.should be_like(%Q{
                "users"."id" IN (SELECT "users"."id", "users"."name" FROM "users")
              })
            end
          end
        end
      end
    end
  end
end
