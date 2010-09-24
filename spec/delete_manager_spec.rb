require 'spec_helper'

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
        dm.to_sql.should be_like %{ DELETE FROM "users" }
      end

      it 'chains' do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new Table.engine
        check dm.from(table).should == dm
      end
    end

    describe 'where' do
      it 'uses where values' do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new Table.engine
        dm.from table
        dm.where table[:id].eq(10)
        dm.to_sql.should be_like %{ DELETE FROM "users" WHERE "users"."id" = 10}
      end

      it 'chains' do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new Table.engine
        check dm.where(table[:id].eq(10)).should == dm
      end
    end

    describe "TreeManager" do
      subject do
        table = Table.new :users
        Arel::DeleteManager.new(Table.engine).tap do |manager|
          manager.where(table[:id].eq(10))
        end
      end

      it_should_behave_like "TreeManager"
    end
  end
end
