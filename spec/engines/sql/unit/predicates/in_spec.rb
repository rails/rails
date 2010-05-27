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

              adapter_is :oracle do
                sql.should be_like(%Q{"USERS"."ID" IN (1, 2, 3)})
              end

              adapter_is_not :mysql, :oracle do
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

              adapter_is :oracle do
                sql.should be_like(%Q{"USERS"."ID" IN (1, 2, 3)})
              end

              adapter_is_not :mysql, :oracle do
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

              adapter_is :oracle do
                sql.should be_like(%Q{"USERS"."ID" IN (NULL)})
              end

              adapter_is_not :mysql, :oracle do
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

            adapter_is :oracle do
              sql.should be_like(%Q{"USERS"."ID" BETWEEN 1 AND 2})
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{"users"."id" BETWEEN 1 AND 2})
            end
          end
        end

        describe 'when relating to a range with an excluded end' do
          before do
            @range = 1...3
          end

          it 'manufactures sql with a >= and <' do
            sql = In.new(@attribute, @range).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{(`users`.`id` >= 1 AND `users`.`id` < 3)})
            end

            adapter_is :oracle do
              sql.should be_like(%Q{("USERS"."ID" >= 1 AND "USERS"."ID" < 3)})
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{("users"."id" >= 1 AND "users"."id" < 3)})
            end
          end
        end

        describe 'when relating to a time range' do
          before do
            @relation = Arel::Table.new(:developers)
            @attribute = @relation[:created_at]
            @range = Time.mktime(2010, 01, 01)..Time.mktime(2010, 02, 01)
          end

          it 'manufactures sql with a between' do
            sql = In.new(@attribute, @range).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{`developers`.`created_at` BETWEEN '2010-01-01 00:00:00' AND '2010-02-01 00:00:00'})
            end

            adapter_is :sqlite3 do
              sql.should match(/"developers"."created_at" BETWEEN '2010-01-01 00:00:00(?:\.\d+)' AND '2010-02-01 00:00:00(?:\.\d+)'/)
            end

            adapter_is :postgresql do
              sql.should be_like(%Q{"developers"."created_at" BETWEEN '2010-01-01 00:00:00.000000' AND '2010-02-01 00:00:00.000000'})
            end

            adapter_is :oracle do
              sql.should be_like(%Q{"DEVELOPERS"."CREATED_AT" BETWEEN TO_TIMESTAMP('2010-01-01 00:00:00:000000','YYYY-MM-DD HH24:MI:SS:FF6') AND TO_TIMESTAMP('2010-02-01 00:00:00:000000','YYYY-MM-DD HH24:MI:SS:FF6')})
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

            adapter_is :oracle do
              sql.should be_like(%Q{
                "USERS"."ID" IN (SELECT "USERS"."ID", "USERS"."NAME" FROM "USERS")
              })
            end

            adapter_is_not :mysql, :oracle do
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
