require 'spec_helper'

module Arel
  describe Join do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end

    describe '#to_sql' do
      describe 'when joining with another relation' do
        it 'manufactures sql joining the two tables on the predicate' do
          sql = InnerJoin.new(@relation1, @relation2, @predicate).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
              FROM `users`
                INNER JOIN `photos` ON `users`.`id` = `photos`.`user_id`
            })
          end

          adapter_is_not :mysql do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name", "photos"."id", "photos"."user_id", "photos"."camera_id"
              FROM "users"
                INNER JOIN "photos" ON "users"."id" = "photos"."user_id"
            })
          end
        end
      end

      describe 'when joining with a string' do
        it "passes the string through to the where clause" do
          sql = StringJoin.new(@relation1, "INNER JOIN asdf ON fdsa").to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`
              FROM `users`
                INNER JOIN asdf ON fdsa
            })
          end

          adapter_is_not :mysql do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name"
              FROM "users"
                INNER JOIN asdf ON fdsa
            })
          end
        end
      end
    end
  end
end
