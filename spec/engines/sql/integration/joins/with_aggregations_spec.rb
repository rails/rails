require 'spec_helper'

module Arel
  describe Join do
    before do
      @relation1 = Table(:users)
      @relation2 = Table(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end

    describe 'when joining aggregated relations' do
      before do
        @aggregation = @relation2                                           \
          .group(@relation2[:user_id])                                      \
          .project(@relation2[:user_id], @relation2[:id].count.as(:cnt))    \
      end

      describe '#to_sql' do
        # CLEANUP
        it '' do
          sql = @relation1.join(@relation2.take(3)).on(@predicate).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`, `photos_external`.`id`, `photos_external`.`user_id`, `photos_external`.`camera_id`
              FROM `users`
              INNER JOIN (SELECT `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id` FROM `photos` LIMIT 3) `photos_external`
                ON `users`.`id` = `photos_external`.`user_id`
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT "USERS"."ID", "USERS"."NAME", "PHOTOS_EXTERNAL"."ID", "PHOTOS_EXTERNAL"."USER_ID", "PHOTOS_EXTERNAL"."CAMERA_ID"
              FROM "USERS"
              INNER JOIN (SELECT "PHOTOS"."ID", "PHOTOS"."USER_ID", "PHOTOS"."CAMERA_ID" FROM "PHOTOS" WHERE ROWNUM <= 3) "PHOTOS_EXTERNAL"
                ON "USERS"."ID" = "PHOTOS_EXTERNAL"."USER_ID"
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name", "photos_external"."id", "photos_external"."user_id", "photos_external"."camera_id"
              FROM "users"
              INNER JOIN (SELECT "photos"."id", "photos"."user_id", "photos"."camera_id" FROM "photos" LIMIT 3) "photos_external"
                ON "users"."id" = "photos_external"."user_id"
            })
          end
        end

        describe 'with the aggregation on the right' do
          it 'manufactures sql joining the left table to a derived table' do
            sql = @relation1.join(@aggregation).on(@predicate).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                SELECT `users`.`id`, `users`.`name`, `photos_external`.`user_id`, `photos_external`.`cnt`
                FROM `users`
                  INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) `photos_external`
                    ON `users`.`id` = `photos_external`.`user_id`
              })
            end

            adapter_is :oracle do
              sql.should be_like(%Q{
                SELECT "USERS"."ID", "USERS"."NAME", "PHOTOS_EXTERNAL"."USER_ID", "PHOTOS_EXTERNAL"."CNT"
                FROM "USERS"
                  INNER JOIN (SELECT "PHOTOS"."USER_ID", COUNT("PHOTOS"."ID") AS "CNT" FROM "PHOTOS" GROUP BY "PHOTOS"."USER_ID") "PHOTOS_EXTERNAL"
                    ON "USERS"."ID" = "PHOTOS_EXTERNAL"."USER_ID"
              })
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{
                SELECT "users"."id", "users"."name", "photos_external"."user_id", "photos_external"."cnt"
                FROM "users"
                  INNER JOIN (SELECT "photos"."user_id", COUNT("photos"."id") AS "cnt" FROM "photos" GROUP BY "photos"."user_id") "photos_external"
                    ON "users"."id" = "photos_external"."user_id"
              })
            end
          end
        end

        describe 'with the aggregation on the left' do
          it 'manufactures sql joining the right table to a derived table' do
            sql = @aggregation.join(@relation1).on(@predicate).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                SELECT `photos_external`.`user_id`, `photos_external`.`cnt`, `users`.`id`, `users`.`name`
                FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) `photos_external`
                  INNER JOIN `users`
                    ON `users`.`id` = `photos_external`.`user_id`
              })
            end

            adapter_is :oracle do
              sql.should be_like(%Q{
                SELECT "PHOTOS_EXTERNAL"."USER_ID", "PHOTOS_EXTERNAL"."CNT", "USERS"."ID", "USERS"."NAME"
                FROM (SELECT "PHOTOS"."USER_ID", COUNT("PHOTOS"."ID") AS "CNT" FROM "PHOTOS" GROUP BY "PHOTOS"."USER_ID") "PHOTOS_EXTERNAL"
                  INNER JOIN "USERS"
                    ON "USERS"."ID" = "PHOTOS_EXTERNAL"."USER_ID"
              })
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{
                SELECT "photos_external"."user_id", "photos_external"."cnt", "users"."id", "users"."name"
                FROM (SELECT "photos"."user_id", COUNT("photos"."id") AS "cnt" FROM "photos" GROUP BY "photos"."user_id") "photos_external"
                  INNER JOIN "users"
                    ON "users"."id" = "photos_external"."user_id"
              })
            end
          end
        end

        describe 'with the aggregation on both sides' do
          it 'it properly aliases the aggregations' do
            aggregation2 = @aggregation.alias
            sql = @aggregation.join(aggregation2).on(aggregation2[:user_id].eq(@aggregation[:user_id])).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                SELECT `photos_external`.`user_id`, `photos_external`.`cnt`, `photos_external_2`.`user_id`, `photos_external_2`.`cnt`
                FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY  `photos`.`user_id`) `photos_external`
                  INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) `photos_external_2`
                    ON `photos_external_2`.`user_id` = `photos_external`.`user_id`
              })
            end

            adapter_is :oracle do
              sql.should be_like(%Q{
                SELECT "PHOTOS_EXTERNAL"."USER_ID", "PHOTOS_EXTERNAL"."CNT", "PHOTOS_EXTERNAL_2"."USER_ID", "PHOTOS_EXTERNAL_2"."CNT"
                FROM (SELECT "PHOTOS"."USER_ID", COUNT("PHOTOS"."ID") AS "CNT" FROM "PHOTOS" GROUP BY  "PHOTOS"."USER_ID") "PHOTOS_EXTERNAL"
                  INNER JOIN (SELECT "PHOTOS"."USER_ID", COUNT("PHOTOS"."ID") AS "CNT" FROM "PHOTOS" GROUP BY "PHOTOS"."USER_ID") "PHOTOS_EXTERNAL_2"
                    ON "PHOTOS_EXTERNAL_2"."USER_ID" = "PHOTOS_EXTERNAL"."USER_ID"
              })
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{
                SELECT "photos_external"."user_id", "photos_external"."cnt", "photos_external_2"."user_id", "photos_external_2"."cnt"
                FROM (SELECT "photos"."user_id", COUNT("photos"."id") AS "cnt" FROM "photos" GROUP BY  "photos"."user_id") "photos_external"
                  INNER JOIN (SELECT "photos"."user_id", COUNT("photos"."id") AS "cnt" FROM "photos" GROUP BY "photos"."user_id") "photos_external_2"
                    ON "photos_external_2"."user_id" = "photos_external"."user_id"
              })
            end
          end
        end

        describe 'when the aggration has a where' do
          describe 'with the aggregation on the left' do
            it "manufactures sql keeping wheres on the aggregation within the derived table" do
              sql = @relation1.join(@aggregation.where(@aggregation[:user_id].eq(1))).on(@predicate).to_sql

              adapter_is :mysql do
                sql.should be_like(%Q{
                  SELECT `users`.`id`, `users`.`name`, `photos_external`.`user_id`, `photos_external`.`cnt`
                  FROM `users`
                    INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` WHERE `photos`.`user_id` = 1 GROUP BY `photos`.`user_id`) `photos_external`
                      ON `users`.`id` = `photos_external`.`user_id`
                })
              end

              adapter_is :oracle do
                sql.should be_like(%Q{
                  SELECT "USERS"."ID", "USERS"."NAME", "PHOTOS_EXTERNAL"."USER_ID", "PHOTOS_EXTERNAL"."CNT"
                  FROM "USERS"
                    INNER JOIN (SELECT "PHOTOS"."USER_ID", COUNT("PHOTOS"."ID") AS "CNT" FROM "PHOTOS" WHERE "PHOTOS"."USER_ID" = 1 GROUP BY "PHOTOS"."USER_ID") "PHOTOS_EXTERNAL"
                      ON "USERS"."ID" = "PHOTOS_EXTERNAL"."USER_ID"
                })
              end

              adapter_is_not :mysql, :oracle do
                sql.should be_like(%Q{
                  SELECT "users"."id", "users"."name", "photos_external"."user_id", "photos_external"."cnt"
                  FROM "users"
                    INNER JOIN (SELECT "photos"."user_id", COUNT("photos"."id") AS "cnt" FROM "photos" WHERE "photos"."user_id" = 1 GROUP BY "photos"."user_id") "photos_external"
                      ON "users"."id" = "photos_external"."user_id"
                })
              end
            end
          end

          describe 'with the aggregation on the right' do
            it "manufactures sql keeping wheres on the aggregation within the derived table" do
              sql = @aggregation.where(@aggregation[:user_id].eq(1)).join(@relation1).on(@predicate).to_sql

              adapter_is :mysql do
                sql.should be_like(%Q{
                  SELECT `photos_external`.`user_id`, `photos_external`.`cnt`, `users`.`id`, `users`.`name`
                  FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` WHERE `photos`.`user_id` = 1 GROUP BY `photos`.`user_id`) `photos_external`
                    INNER JOIN `users`
                      ON `users`.`id` = `photos_external`.`user_id`
                })
              end

              adapter_is :oracle do
                sql.should be_like(%Q{
                  SELECT "PHOTOS_EXTERNAL"."USER_ID", "PHOTOS_EXTERNAL"."CNT", "USERS"."ID", "USERS"."NAME"
                  FROM (SELECT "PHOTOS"."USER_ID", COUNT("PHOTOS"."ID") AS "CNT" FROM "PHOTOS" WHERE "PHOTOS"."USER_ID" = 1 GROUP BY "PHOTOS"."USER_ID") "PHOTOS_EXTERNAL"
                    INNER JOIN "USERS"
                      ON "USERS"."ID" = "PHOTOS_EXTERNAL"."USER_ID"
                })
              end

              adapter_is_not :mysql, :oracle do
                sql.should be_like(%Q{
                  SELECT "photos_external"."user_id", "photos_external"."cnt", "users"."id", "users"."name"
                  FROM (SELECT "photos"."user_id", COUNT("photos"."id") AS "cnt" FROM "photos" WHERE "photos"."user_id" = 1 GROUP BY "photos"."user_id") "photos_external"
                    INNER JOIN "users"
                      ON "users"."id" = "photos_external"."user_id"
                })
              end
            end
          end
        end
      end
    end
  end
end
