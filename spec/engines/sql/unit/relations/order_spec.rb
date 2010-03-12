require 'spec_helper'

module Arel
  describe Order do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe '#to_sql' do
      describe "when given an attribute" do
        it "manufactures sql with an order clause populated by the attribute" do
          sql = Order.new(@relation, @attribute).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`
              FROM `users`
              ORDER BY `users`.`id` ASC
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT "USERS"."ID", "USERS"."NAME"
              FROM "USERS"
              ORDER BY "USERS"."ID" ASC
            })

            distinct_attributes = ActiveRecord::Base.connection.distinct('"USERS"."NAME"', '"USERS"."ID"')
            @relation.project(distinct_attributes).order(@relation[:id]).to_sql.should be_like(%Q{
              SELECT DISTINCT "USERS"."NAME",
              FIRST_VALUE("USERS"."ID") OVER (PARTITION BY "USERS"."NAME" ORDER BY "USERS"."ID") AS alias_0__
              FROM "USERS"
              ORDER BY alias_0__
            })

            distinct_attributes = ActiveRecord::Base.connection.distinct('"USERS"."NAME"', '"USERS"."ID" DESC')
            @relation.project(distinct_attributes).order('"USERS"."ID" DESC').to_sql.should be_like(%Q{
              SELECT DISTINCT "USERS"."NAME",
              FIRST_VALUE("USERS"."ID") OVER (PARTITION BY "USERS"."NAME" ORDER BY "USERS"."ID" DESC) AS alias_0__
              FROM "USERS"
              ORDER BY alias_0__ DESC
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name"
              FROM "users"
              ORDER BY "users"."id" ASC
            })
          end
        end
      end

      describe "when given multiple attributes" do
        before do
          @another_attribute = @relation[:name]
        end

        it "manufactures sql with an order clause populated by comma-separated attributes" do
          sql = Order.new(@relation, @attribute, @another_attribute).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`
              FROM `users`
              ORDER BY `users`.`id` ASC, `users`.`name` ASC
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT "USERS"."ID", "USERS"."NAME"
              FROM "USERS"
              ORDER BY "USERS"."ID" ASC, "USERS"."NAME" ASC
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name"
              FROM "users"
              ORDER BY "users"."id" ASC, "users"."name" ASC
            })
          end
        end
      end

      describe "when given a string" do
        before do
          @string = "asdf"
        end

        it "passes the string through to the order clause" do
          sql = Order.new(@relation, @string).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`
              FROM `users`
              ORDER BY asdf
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT "USERS"."ID", "USERS"."NAME"
              FROM "USERS"
              ORDER BY asdf
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name"
              FROM "users"
              ORDER BY asdf
            })
          end
        end
      end

      describe "when ordering an ordered relation" do
        before do
          @ordered_relation = Order.new(@relation, @attribute)
          @another_attribute = @relation[:name]
        end

        it "manufactures sql with the order clause of the last ordering preceding the first ordering" do
          sql = Order.new(@ordered_relation, @another_attribute).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`
              FROM `users`
              ORDER BY `users`.`name` ASC, `users`.`id` ASC
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT "USERS"."ID", "USERS"."NAME"
              FROM "USERS"
              ORDER BY "USERS"."NAME" ASC, "USERS"."ID" ASC
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name"
              FROM "users"
              ORDER BY "users"."name" ASC, "users"."id" ASC
            })
          end
        end
      end
    end
  end
end
