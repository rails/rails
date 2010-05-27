require 'spec_helper'
require 'bigdecimal'

module Arel
  describe "Attributes::String" do

    before :all do
      @relation = Model.build do |r|
        r.engine Testing::Engine.new
        r.attribute :name, Attributes::String
      end
    end

    def type_cast(val)
      @relation[:name].type_cast(val)
    end

    describe "#type_cast" do
      it "returns same value if passed a String" do
        val = "hell"
        type_cast(val).should eql(val)
      end

      it "returns nil if passed nil" do
        type_cast(nil).should be_nil
      end

      it "returns String representation of Symbol" do
        type_cast(:hello).should == "hello"
      end

      it "returns string representation of Integer" do
        type_cast(1).should == '1'
      end

      it "calls #to_s on arbitrary objects" do
        obj = Object.new
        obj.extend Module.new { def to_s ; 'hello' ; end }
        type_cast(obj).should == 'hello'
      end
    end
  end
end
