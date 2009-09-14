require 'spec_helper'

module Arel
  describe Skip do
    before do
      @relation = Table.new(:users)
      @skipped = 4
    end

    describe '#to_sql' do
      it "manufactures sql with limit and offset" do
        sql = Skip.new(@relation, @skipped).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            OFFSET 4
          })
        end

        adapter_is_not :mysql do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM "users"
            OFFSET 4
          })
        end
      end
    end
  end
end
