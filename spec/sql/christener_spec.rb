require 'spec_helper'

module Arel
  module Sql
    describe "Christener" do
      it "returns the first name" do
        christener = Christener.new
        table = Table.new 'users'
        table2 = Table.new 'pictures'
        christener.name_for(table).should == 'users'
        christener.name_for(table2).should == 'pictures'
        christener.name_for(table).should == 'users'
      end

      it "returns a unique name for an alias" do
        christener = Christener.new
        table = Table.new 'users'
        table2 = Table.new 'users', :as => 'friends'
        christener.name_for(table).should == 'users'
        christener.name_for(table2).should == 'friends'
      end

      it "returns a unique name for an alias with same name" do
        christener = Christener.new
        table = Table.new 'users'
        table2 = Table.new 'friends', :as => 'users'
        christener.name_for(table).should == 'users'
        christener.name_for(table2).should == 'users_2'
      end

      it "returns alias name" do
        christener = Christener.new
        table = Table.new 'users'
        aliaz = Alias.new table

        christener.name_for(table).should == 'users'
        christener.name_for(aliaz).should == 'users_2'
      end

      it "returns alias first" do
        christener = Christener.new
        table = Table.new 'users'
        aliaz = Alias.new table

        christener.name_for(aliaz).should == 'users'
        christener.name_for(table).should == 'users_2'
      end

      it "returns externalization name" do
        christener = Christener.new
        table = Table.new 'users'
        ext = Externalization.new table

        christener.name_for(table).should == 'users'
        christener.name_for(ext).should == 'users_external'
      end

      it "returns aliases externalizations and tables" do
        christener = Christener.new
        table = Table.new 'users'
        aliaz = Alias.new table
        ext = Externalization.new table

        christener.name_for(table).should == 'users'
        christener.name_for(aliaz).should == 'users_2'
        christener.name_for(ext).should == 'users_external'
      end
    end
  end
end
