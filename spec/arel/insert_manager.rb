require 'spec_helper'

module Arel
  describe 'insert manager' do
    describe 'new' do
      it 'takes an engine' do
        Arel::InsertManager.new Table.engine
      end
    end

    describe 'into' do
      it 'takes an engine' do
        manager = Arel::InsertManager.new Table.engine
        manager.into(Table.new(:users)).should == manager
      end
    end

    describe 'to_sql' do
      it 'converts to sql' do
        table   = Table.new :users
        manager = Arel::InsertManager.new Table.engine
        manager.into table
        manager.to_sql.should be_like %{
          INSERT INTO "users"
        }
      end
    end
  end
end
