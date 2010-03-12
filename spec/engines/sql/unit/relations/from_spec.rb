require 'spec_helper'

module Arel
  describe Table do
    before do
      @relation = Table.new(:users)
    end

    describe '#to_sql' do
      it "manufactures a simple select query" do
        sql = @relation.from("workers").to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            SELECT `users`.`id`, `users`.`name`
            FROM workers
          })
        end

        adapter_is :oracle do
          sql.should be_like(%Q{
            SELECT "USERS"."ID", "USERS"."NAME"
            FROM workers
          })
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM workers
          })
        end
      end
    end

    describe '#to_sql' do
      it "overrides and use last from clause given " do
        sql = @relation.from("workers").from("users").to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            SELECT `users`.`id`, `users`.`name`
            FROM users
          })
        end

        adapter_is :oracle do
          sql.should be_like(%Q{
            SELECT "USERS"."ID", "USERS"."NAME"
            FROM users
          })
        end

        adapter_is_not :mysql, :oracle do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM users
          })
        end
      end
    end

  end
end
