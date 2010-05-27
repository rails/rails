require 'spec_helper'

module Arel
  describe "Attributes::Boolean" do

    before :all do
      @relation = Model.build do |r|
        r.engine Testing::Engine.new
        r.attribute :awesome, Attributes::Boolean
      end
    end

    def type_cast(val)
      @relation[:awesome].type_cast(val)
    end

    describe "#type_cast" do
      it "returns same value if passed a boolean" do
        val = true
        type_cast(val).should eql(val)
      end

      it "returns boolean representation (false) of nil" do
        type_cast(nil).should eql(false)
      end

      it "returns boolean representation of 'true', 'false'" do
        type_cast('true').should eql(true)
        type_cast('false').should eql(false)
      end

      it "returns boolean representation of :true, :false" do
        type_cast(:true).should eql(true)
        type_cast(:false).should eql(false)
      end

      it "returns boolean representation of 0, 1" do
        type_cast(1).should == true
        type_cast(0).should == false
      end

      it "calls #to_s on arbitrary objects" do
        obj = Object.new
        obj.extend Module.new { def to_s ; 'true' ; end }
        type_cast(obj).should == true
      end

      [ Object.new, 'string', '00.0', 5 ].each do |value|
        it "raises exception when attempting type_cast of non-boolean value #{value.inspect}" do
          lambda do
            type_cast(value)
          end.should raise_error(TypecastError, /could not typecast/)
        end
      end
    end
  end
end
