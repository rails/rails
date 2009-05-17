require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

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

        adapter_is_not :mysql do
          sql.should be_like(%Q{
            UPDATE "users"
            SET "id" = 1, "name" = 'nick'
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

        adapter_is_not :mysql do
          sql.should be_like(%Q{
            UPDATE "users"
            SET "name" = 'nick'
            LIMIT 1
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

          adapter_is_not :mysql do
            @update.to_sql.should be_like(%Q{
              UPDATE "users"
              SET "name" = 'nick'
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

          adapter_is_not :mysql do
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

          adapter_is_not :mysql do
            @update.to_sql.should be_like(%Q{
              UPDATE "users"
              SET "name" = 'nick'
              WHERE "users"."id" = 1
            })
          end
        end
      end
    end

    describe '#call' do
      before do
        @update = Update.new(@relation, @relation[:name] => "nick")
      end

      it 'executes an update on the connection' do
        mock(connection = Object.new).update(@update.to_sql)
        @update.call(connection)
      end
    end

  end
end
