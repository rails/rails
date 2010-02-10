require 'spec_helper'

module Arel
  describe Project do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe '#to_sql' do
      describe 'when given an attribute' do
        it "manufactures sql with a limited select clause" do
          sql = Project.new(@relation, @attribute).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`
              FROM `users`
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT "USERS"."ID"
              FROM "USERS"
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT "users"."id"
              FROM "users"
            })
          end
        end
      end

      describe 'when given a relation' do
        before do
          @scalar_relation = Project.new(@relation, @relation[:name])
        end

        it "manufactures sql with scalar selects" do
          sql = Project.new(@relation, @scalar_relation).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT (SELECT `users`.`name` FROM `users`) AS `users` FROM `users`
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT (SELECT "USERS"."NAME" FROM "USERS") AS "USERS" FROM "USERS"
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT (SELECT "users"."name" FROM "users") AS "users" FROM "users"
            })
          end
        end
      end

      describe 'when given a string' do
        it "passes the string through to the select clause" do
          sql = Project.new(@relation, 'asdf').to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT asdf FROM `users`
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT asdf FROM "USERS"
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT asdf FROM "users"
            })
          end
        end
      end

      describe 'when given an expression' do
        it 'manufactures sql with expressions' do
          sql = @relation.project(@attribute.count).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT COUNT(`users`.`id`) AS count_id
              FROM `users`
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT COUNT("USERS"."ID") AS count_id
              FROM "USERS"
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT COUNT("users"."id") AS count_id
              FROM "users"
            })
          end
        end

        it 'manufactures sql with distinct expressions' do
          sql = @relation.project(@attribute.count(true)).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT COUNT(DISTINCT `users`.`id`) AS count_id
              FROM `users`
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT COUNT(DISTINCT "USERS"."ID") AS count_id
              FROM "USERS"
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT COUNT(DISTINCT "users"."id") AS count_id
              FROM "users"
            })
          end
        end
      end
    end
  end
end
