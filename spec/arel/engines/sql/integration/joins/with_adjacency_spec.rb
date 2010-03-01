require 'spec_helper'

module Arel
  describe Join do
    before do
      @relation1 = Table(:users)
      @relation2 = @relation1.alias
      @predicate = @relation1[:id].eq(@relation2[:id])
    end

    describe 'when joining a relation to itself' do
      describe '#to_sql' do
        it 'manufactures sql aliasing the table and attributes properly in the join predicate and the where clause' do
          sql = @relation1.join(@relation2).on(@predicate).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`, `users_2`.`id`, `users_2`.`name`
              FROM `users`
                INNER JOIN `users` `users_2`
                  ON `users`.`id` = `users_2`.`id`
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT "USERS"."ID", "USERS"."NAME", "USERS_2"."ID", "USERS_2"."NAME"
              FROM "USERS"
                INNER JOIN "USERS" "USERS_2"
                  ON "USERS"."ID" = "USERS_2"."ID"
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name", "users_2"."id", "users_2"."name"
              FROM "users"
                INNER JOIN "users" "users_2"
                  ON "users"."id" = "users_2"."id"
            })
          end
        end

        describe 'when joining with a where on the same relation' do
          it 'manufactures sql aliasing the tables properly' do
            sql = @relation1                                 \
              .join(@relation2.where(@relation2[:id].eq(1))) \
                .on(@predicate)                              \
            .to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                SELECT `users`.`id`, `users`.`name`, `users_2`.`id`, `users_2`.`name`
                FROM `users`
                  INNER JOIN `users` `users_2`
                    ON `users`.`id` = `users_2`.`id` AND `users_2`.`id` = 1
              })
            end

            adapter_is :oracle do
              sql.should be_like(%Q{
                SELECT "USERS"."ID", "USERS"."NAME", "USERS_2"."ID", "USERS_2"."NAME"
                FROM "USERS"
                  INNER JOIN "USERS" "USERS_2"
                    ON "USERS"."ID" = "USERS_2"."ID" AND "USERS_2"."ID" = 1
              })
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{
                SELECT "users"."id", "users"."name", "users_2"."id", "users_2"."name"
                FROM "users"
                  INNER JOIN "users" "users_2"
                    ON "users"."id" = "users_2"."id" AND "users_2"."id" = 1
              })
            end
          end

          describe 'when the where occurs before the alias' do
            it 'manufactures sql aliasing the predicates properly' do
              relation2 = @relation1.where(@relation1[:id].eq(1)).alias

              sql = @relation1                            \
                .join(relation2)                          \
                  .on(relation2[:id].eq(@relation1[:id])) \
              .to_sql

              adapter_is :mysql do
                sql.should be_like(%Q{
                  SELECT `users`.`id`, `users`.`name`, `users_2`.`id`, `users_2`.`name`
                  FROM `users`
                  INNER JOIN `users` `users_2`
                    ON `users_2`.`id` = `users`.`id` AND `users_2`.`id` = 1
                })
              end

              adapter_is :oracle do
                sql.should be_like(%Q{
                  SELECT "USERS"."ID", "USERS"."NAME", "USERS_2"."ID", "USERS_2"."NAME"
                  FROM "USERS"
                  INNER JOIN "USERS" "USERS_2"
                    ON "USERS_2"."ID" = "USERS"."ID" AND "USERS_2"."ID" = 1
                })
              end

              adapter_is_not :mysql, :oracle do
                sql.should be_like(%Q{
                  SELECT "users"."id", "users"."name", "users_2"."id", "users_2"."name"
                  FROM "users"
                  INNER JOIN "users" "users_2"
                    ON "users_2"."id" = "users"."id" AND "users_2"."id" = 1
                })
              end
            end
          end
        end

        describe 'when joining the relation to itself multiple times' do
          before do
            @relation3 = @relation1.alias
          end

          describe 'when joining left-associatively' do
            it 'manufactures sql aliasing the tables properly' do
              sql = @relation1                                \
                .join(@relation2                              \
                  .join(@relation3)                           \
                    .on(@relation2[:id].eq(@relation3[:id]))) \
                  .on(@relation1[:id].eq(@relation2[:id]))                                 \
              .to_sql

              adapter_is :mysql do
                sql.should be_like(%Q{
                  SELECT `users`.`id`, `users`.`name`, `users_2`.`id`, `users_2`.`name`, `users_3`.`id`, `users_3`.`name`
                  FROM `users`
                    INNER JOIN `users` `users_2`
                      ON `users`.`id` = `users_2`.`id`
                    INNER JOIN `users` `users_3`
                      ON `users_2`.`id` = `users_3`.`id`
                })
              end

              adapter_is :oracle do
                sql.should be_like(%Q{
                  SELECT "USERS"."ID", "USERS"."NAME", "USERS_2"."ID", "USERS_2"."NAME", "USERS_3"."ID", "USERS_3"."NAME"
                  FROM "USERS"
                    INNER JOIN "USERS" "USERS_2"
                      ON "USERS"."ID" = "USERS_2"."ID"
                    INNER JOIN "USERS" "USERS_3"
                      ON "USERS_2"."ID" = "USERS_3"."ID"
                })
              end

              adapter_is_not :mysql, :oracle do
                sql.should be_like(%Q{
                  SELECT "users"."id", "users"."name", "users_2"."id", "users_2"."name", "users_3"."id", "users_3"."name"
                  FROM "users"
                    INNER JOIN "users" "users_2"
                      ON "users"."id" = "users_2"."id"
                    INNER JOIN "users" "users_3"
                      ON "users_2"."id" = "users_3"."id"
                })
              end
            end
          end

          describe 'when joining right-associatively' do
            it 'manufactures sql aliasing the tables properly' do
              sql = @relation1                                              \
                .join(@relation2).on(@relation1[:id].eq(@relation2[:id]))   \
                .join(@relation3).on(@relation2[:id].eq(@relation3[:id]))   \
              .to_sql

              adapter_is :mysql do
                sql.should be_like(%Q{
                  SELECT `users`.`id`, `users`.`name`, `users_2`.`id`, `users_2`.`name`, `users_3`.`id`, `users_3`.`name`
                  FROM `users`
                    INNER JOIN `users` `users_2`
                      ON `users`.`id` = `users_2`.`id`
                    INNER JOIN `users` `users_3`
                      ON `users_2`.`id` = `users_3`.`id`
                })
              end

              adapter_is :oracle do
                sql.should be_like(%Q{
                  SELECT "USERS"."ID", "USERS"."NAME", "USERS_2"."ID", "USERS_2"."NAME", "USERS_3"."ID", "USERS_3"."NAME"
                  FROM "USERS"
                    INNER JOIN "USERS" "USERS_2"
                      ON "USERS"."ID" = "USERS_2"."ID"
                    INNER JOIN "USERS" "USERS_3"
                      ON "USERS_2"."ID" = "USERS_3"."ID"
                })
              end

              adapter_is_not :mysql, :oracle do
                sql.should be_like(%Q{
                  SELECT "users"."id", "users"."name", "users_2"."id", "users_2"."name", "users_3"."id", "users_3"."name"
                  FROM "users"
                    INNER JOIN "users" "users_2"
                      ON "users"."id" = "users_2"."id"
                    INNER JOIN "users" "users_3"
                      ON "users_2"."id" = "users_3"."id"
                })
              end
            end
          end
        end
      end

      describe '[]' do
        describe 'when given an attribute belonging to both sub-relations' do
          it 'disambiguates the relation that serves as the ancestor to the attribute' do
            @relation1          \
              .join(@relation2) \
                .on(@predicate) \
            .should disambiguate_attributes(@relation1[:id], @relation2[:id])
          end

          describe 'when both relations are compound and only one is an alias' do
            it 'disambiguates the relation that serves as the ancestor to the attribute' do
              compound1 = @relation1.where(@predicate)
              compound2 = compound1.alias
              compound1           \
                .join(compound2)  \
                  .on(@predicate) \
              .should disambiguate_attributes(compound1[:id], compound2[:id])
            end
          end

          describe 'when the left relation is extremely compound' do
            it 'disambiguates the relation that serves as the ancestor to the attribute' do
              @relation1            \
                .where(@predicate)  \
                .where(@predicate)  \
                .join(@relation2)   \
                  .on(@predicate)   \
              .should disambiguate_attributes(@relation1[:id], @relation2[:id])
            end
          end

          describe 'when the right relation is extremely compound' do
            it 'disambiguates the relation that serves as the ancestor to the attribute' do
              @relation1                  \
                .join(                    \
                  @relation2              \
                    .where(@predicate)    \
                    .where(@predicate)    \
                    .where(@predicate))   \
                  .on(@predicate)         \
              .should disambiguate_attributes(@relation1[:id], @relation2[:id])
            end
          end
        end
      end
    end
  end
end
