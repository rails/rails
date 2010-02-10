require 'spec_helper'

class User
  def self.primary_key
    "id"
  end
end

module Arel
  describe Update do
    before do
      @relation = Table.new(:users)
    end

    describe '#to_sql' do
      it "manufactures sql updating attributes when given multiple attributes" do
        sql = Update.new(@relation, @relation[:id] => 1, @relation[:name] => "nick").to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            UPDATE `users`
            SET `id` = 1, `name` = 'nick'
          })
        end

        adapter_is :sqlite3 do
          sql.should be_like(%Q{
            UPDATE "users"
            SET "id" = 1, "name" = 'nick'
          })
        end

        adapter_is :postgresql do
          sql.should be_like(%Q{
            UPDATE "users"
            SET "id" = 1, "name" = E'nick'
          })
        end

        adapter_is :oracle do
          sql.should be_like(%Q{
            UPDATE "USERS"
            SET "ID" = 1, "NAME" = 'nick'
          })
        end
      end

      it "manufactures sql updating attributes when given a ranged relation" do
        sql = Update.new(@relation.take(1), @relation[:name] => "nick").to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            UPDATE `users`
            SET `name` = 'nick'
            LIMIT 1
          })
        end

        adapter_is :sqlite3 do
          sql.should be_like(%Q{
            UPDATE "users" SET
            "name" = 'nick'
            WHERE "id" IN (SELECT "id" FROM "users"  LIMIT 1)
          })
        end

        adapter_is :postgresql do
          sql.should be_like(%Q{
            UPDATE "users" SET
            "name" = E'nick'
            WHERE "id" IN (SELECT "id" FROM "users"  LIMIT 1)
          })
        end

        adapter_is :oracle do
          sql.should be_like(%Q{
            UPDATE "USERS" SET
            "NAME" = 'nick'
            WHERE "ID" IN (SELECT "ID" FROM "USERS" WHERE ROWNUM <= 1)
          })

          sql_with_order_by = Update.new(@relation.order(@relation[:id]).take(1), @relation[:name] => "nick").to_sql
          sql_with_order_by.should be_like(%Q{
            UPDATE "USERS" SET
            "NAME" = 'nick'
            WHERE "ID" IN (select * from
                          (SELECT "ID" FROM "USERS" ORDER BY "USERS"."ID" ASC)
                          where rownum <= 1)
          })
        end
      end

      describe 'when given values whose types correspond to the types of the attributes' do
        before do
          @update = Update.new(@relation, @relation[:name] => "nick")
        end

        it 'manufactures sql updating attributes' do
          adapter_is :mysql do
            @update.to_sql.should be_like(%Q{
              UPDATE `users`
              SET `name` = 'nick'
            })
          end

          adapter_is :sqlite3 do
            @update.to_sql.should be_like(%Q{
              UPDATE "users"
              SET "name" = 'nick'
            })
          end

          adapter_is :postgresql do
            @update.to_sql.should be_like(%Q{
              UPDATE "users"
              SET "name" = E'nick'
            })
          end

          adapter_is :oracle do
            @update.to_sql.should be_like(%Q{
              UPDATE "USERS"
              SET "NAME" = 'nick'
            })
          end
        end
      end

      describe 'when given values whose types differ from from the types of the attributes' do
        before do
          @update = Update.new(@relation, @relation[:id] => '1-asdf')
        end

        it 'manufactures sql updating attributes' do
          adapter_is :mysql do
            @update.to_sql.should be_like(%Q{
              UPDATE `users`
              SET `id` = 1
            })
          end

          adapter_is :oracle do
            @update.to_sql.should be_like(%Q{
              UPDATE "USERS"
              SET "ID" = 1
            })
          end

          adapter_is_not :mysql, :oracle do
            @update.to_sql.should be_like(%Q{
              UPDATE "users"
              SET "id" = 1
            })
          end
        end
      end

      describe 'when the relation is a where' do
        before do
          @update = Update.new(
            @relation.where(@relation[:id].eq(1)),
            @relation[:name] => "nick"
          )
        end

        it 'manufactures sql updating a where relation' do
          adapter_is :mysql do
            @update.to_sql.should be_like(%Q{
              UPDATE `users`
              SET `name` = 'nick'
              WHERE `users`.`id` = 1
            })
          end

          adapter_is :sqlite3 do
            @update.to_sql.should be_like(%Q{
              UPDATE "users"
              SET "name" = 'nick'
              WHERE "users"."id" = 1
            })
          end

          adapter_is :postgresql do
            @update.to_sql.should be_like(%Q{
              UPDATE "users"
              SET "name" = E'nick'
              WHERE "users"."id" = 1
            })
          end

          adapter_is :oracle do
            @update.to_sql.should be_like(%Q{
              UPDATE "USERS"
              SET "NAME" = 'nick'
              WHERE "USERS"."ID" = 1
            })
          end
        end
      end
    end

  end
end
