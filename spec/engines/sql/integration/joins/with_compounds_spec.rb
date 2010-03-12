require 'spec_helper'

module Arel
  describe Join do
    before do
      @relation1 = Table(:users)
      @relation2 = Table(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end

    describe '#to_sql' do
      describe 'when the join contains a where' do
        describe 'and the where is given a string' do
          it 'does not escape the string' do
            sql = @relation1                    \
              .join(@relation2.where("asdf"))   \
                .on(@predicate)                 \
            .to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
                FROM `users`
                INNER JOIN `photos`
                  ON `users`.`id` = `photos`.`user_id` AND asdf
              })
            end

            adapter_is :oracle do
              sql.should be_like(%Q{
                SELECT "USERS"."ID", "USERS"."NAME", "PHOTOS"."ID", "PHOTOS"."USER_ID", "PHOTOS"."CAMERA_ID"
                FROM "USERS"
                INNER JOIN "PHOTOS"
                  ON "USERS"."ID" = "PHOTOS"."USER_ID" AND asdf
              })
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{
                SELECT "users"."id", "users"."name", "photos"."id", "photos"."user_id", "photos"."camera_id"
                FROM "users"
                INNER JOIN "photos"
                  ON "users"."id" = "photos"."user_id" AND asdf
              })
            end
          end
        end
      end

      describe 'when a compound contains a join' do
        describe 'and the compound is a where' do
          it 'manufactures sql disambiguating the tables' do
            sql = @relation1                  \
              .where(@relation1[:id].eq(1))   \
              .join(@relation2)               \
                .on(@predicate)               \
              .where(@relation1[:id].eq(1))   \
            .to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
                FROM `users`
                INNER JOIN `photos`
                  ON `users`.`id` = `photos`.`user_id`
                WHERE `users`.`id` = 1
                  AND `users`.`id` = 1
              })
            end

            adapter_is :oracle do
              sql.should be_like(%Q{
                SELECT "USERS"."ID", "USERS"."NAME", "PHOTOS"."ID", "PHOTOS"."USER_ID", "PHOTOS"."CAMERA_ID"
                FROM "USERS"
                INNER JOIN "PHOTOS"
                  ON "USERS"."ID" = "PHOTOS"."USER_ID"
                WHERE "USERS"."ID" = 1
                  AND "USERS"."ID" = 1
              })
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{
                SELECT "users"."id", "users"."name", "photos"."id", "photos"."user_id", "photos"."camera_id"
                FROM "users"
                INNER JOIN "photos"
                  ON "users"."id" = "photos"."user_id"
                WHERE "users"."id" = 1
                  AND "users"."id" = 1
              })
            end
          end
        end

        describe 'and the compound is a group' do
          it 'manufactures sql disambiguating the tables' do
            sql = @relation1          \
              .join(@relation2)       \
                .on(@predicate)       \
              .group(@relation1[:id]) \
            .to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
                FROM `users`
                INNER JOIN `photos`
                  ON `users`.`id` = `photos`.`user_id`
                GROUP BY `users`.`id`
              })
            end

            adapter_is :oracle do
              sql.should be_like(%Q{
                SELECT "USERS"."ID", "USERS"."NAME", "PHOTOS"."ID", "PHOTOS"."USER_ID", "PHOTOS"."CAMERA_ID"
                FROM "USERS"
                INNER JOIN "PHOTOS"
                  ON "USERS"."ID" = "PHOTOS"."USER_ID"
                GROUP BY "USERS"."ID"
              })
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{
                SELECT "users"."id", "users"."name", "photos"."id", "photos"."user_id", "photos"."camera_id"
                FROM "users"
                INNER JOIN "photos"
                  ON "users"."id" = "photos"."user_id"
                GROUP BY "users"."id"
              })
            end
          end
        end
      end
    end
  end
end
