require 'spec_helper'

module Arel
  describe Take do
    before do
      @relation = Table.new(:users)
      @taken = 4
    end

    describe '#to_sql' do
      it "manufactures sql with limit and offset" do
        sql = Take.new(@relation, @taken).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            SELECT `users`.`id`, `users`.`name`
            FROM `users`
            LIMIT 4
          })
        end

        adapter_is_not :mysql do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM "users"
            LIMIT 4
          })
        end
      end
    end
  end
end
