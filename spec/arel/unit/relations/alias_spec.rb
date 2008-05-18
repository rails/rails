require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Alias do
    before do
      @relation = Table.new(:users)
    end
    
    describe '==' do
      it "obtains if the objects are the same" do
        Alias.new(@relation).should_not == Alias.new(@relation)
        (aliaz = Alias.new(@relation)).should == aliaz
      end
    end
  end
end