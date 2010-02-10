require 'spec_helper'

module Arel
  describe Deletion do
    before do
      @relation = Table.new(:users)
    end

    describe '#to_sql' do
      it 'manufactures sql deleting a table relation' do
        sql = Deletion.new(@relation).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{DELETE FROM `users`})
        end

        adapter_is :oracle do
          sql.should be_like(%Q{DELETE FROM "USERS"})
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{DELETE FROM "users"})
        end
      end

      it 'manufactures sql deleting a where relation' do
        sql = Deletion.new(@relation.where(@relation[:id].eq(1))).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            DELETE
            FROM `users`
            WHERE `users`.`id` = 1
          })
        end

        adapter_is :oracle do
          sql.should be_like(%Q{
            DELETE
            FROM "USERS"
            WHERE "USERS"."ID" = 1
          })
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{
            DELETE
            FROM "users"
            WHERE "users"."id" = 1
          })
        end
      end

      it "manufactures sql deleting a ranged relation" do
        sql = Deletion.new(@relation.take(1)).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            DELETE
            FROM `users`
            LIMIT 1
          })
        end

        adapter_is :oracle do
          sql.should be_like(%Q{
            DELETE
            FROM "USERS"
            WHERE ROWNUM <= 1
          })
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{
            DELETE
            FROM "users"
            LIMIT 1
          })
        end
      end
    end
  end
end
