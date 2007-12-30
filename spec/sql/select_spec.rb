require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Select, '==' do
  it "obtains for queries with identical attributes" do
    Select.new(:foo).should == Select.new(:foo)
    Select.new(:bar).should_not == Select.new(:foo)
  end
  
  it "obtains for queries with identical tables" do
    Select.new(:foo).from(:bar).should == Select.new(:foo).from(:bar)
    Select.new(:foo).from(:bar).should_not == Select.new(:foo).from(:foo)
  end
  
  it "obtains for queries with identical predicates" do
    Select.new(:foo).from(:bar).where(:baz).should == Select.new(:foo).from(:bar).where(:baz)
    Select.new(:foo).from(:bar).where(:baz).should_not == Select.new(:foo).from(:bar).where(:foo)
  end
  
end