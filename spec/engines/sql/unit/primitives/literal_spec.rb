require 'spec_helper'

module Arel
  describe SqlLiteral do
    before do
      @relation = Table.new(:users)
    end

    describe '#to_sql' do
      it "manufactures sql with a literal SQL fragment" do
        sql = @relation.project(Count.new(SqlLiteral.new("*"))).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{SELECT COUNT(*) AS count_id FROM `users`})
        end

        adapter_is :oracle do
          sql.should be_like(%Q{SELECT COUNT(*) AS count_id FROM "USERS"})
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{SELECT COUNT(*) AS count_id FROM "users"})
        end
      end

      it "manufactures expressions on literal SQL fragment" do
        sql = @relation.project(SqlLiteral.new("2 * credit_limit").sum).to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{SELECT SUM(2 * credit_limit) AS sum_id FROM `users`})
        end

        adapter_is :oracle do
          sql.should be_like(%Q{SELECT SUM(2 * credit_limit) AS sum_id FROM "USERS"})
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{SELECT SUM(2 * credit_limit) AS sum_id FROM "users"})
        end
      end
    end
  end
end
