require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Alias do
    before do
      @relation = Table.new(:users)
      @alias_relation = Alias.new(@relation, :foo)
    end
    
    describe '#alias' do
      it "returns the alias" do
        @alias_relation.alias.should == :foo
      end
    end
  end
end