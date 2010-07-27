require 'spec_helper'

module Arel
  FakeAR = Struct.new(:connection)
  class FakeConnection < Struct.new :called
    def initialize c = []; super; end

    def method_missing name, *args, &block
      called << [name, args, block]
    end
  end

  describe Sql::Engine do
    before do
      @users = Table.new(:users)
      @users.delete
    end

    describe "method missing" do
      it "should ask for a connection" do
        conn   = FakeConnection.new
        ar     = FakeAR.new conn
        engine = Arel::Sql::Engine.new ar

        ar.connection = nil
        lambda { engine.foo }.should raise_error
      end
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
