require 'helper'

module Arel
  describe 'delete manager' do
    describe 'new' do
      it 'takes an engine' do
        Arel::DeleteManager.new Table.engine
      end
    end

    describe 'from' do
      it 'uses from' do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new Table.engine
        dm.from table
        dm.to_sql.must_be_like %{ DELETE FROM "users" }
      end

      it 'chains' do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new Table.engine
        dm.from(table).must_equal dm
      end
    end

    describe 'where' do
      it 'uses where values' do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new Table.engine
        dm.from table
        dm.where table[:id].eq(10)
        dm.to_sql.must_be_like %{ DELETE FROM "users" WHERE "users"."id" = 10}
      end

      it 'chains' do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new Table.engine
        dm.where(table[:id].eq(10)).must_equal dm
      end
    end
  end
end
