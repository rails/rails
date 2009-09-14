require 'spec_helper'

module Arel
  describe Sql::Engine do
    before do
      @users = Table.new(:users)
      @users.delete
    end

    describe "CRUD" do
      describe "#create" do
        it "inserts into the relation" do
          @users.insert @users[:name] => "Bryan"
          @users.first[@users[:name]].should == "Bryan"
        end
      end

      describe "#read" do
        it "reads from the relation" do
          @users.insert @users[:name] => "Bryan"

          @users.each do |row|
            row[@users[:name]].should == "Bryan"
          end
        end
      end

      describe "#update" do
        it "updates the relation" do
          @users.insert @users[:name] => "Nick"
          @users.update @users[:name] => "Bryan"
          @users.first[@users[:name]].should == "Bryan"
        end
      end

      describe "#delete" do
        it "deletes from the relation" do
          @users.insert @users[:name] => "Bryan"
          @users.delete
          @users.first.should == nil
        end
      end
    end
  end
end
