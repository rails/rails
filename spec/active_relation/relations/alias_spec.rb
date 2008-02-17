require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Alias do
    before do
      @relation = Table.new(:users)
      @alias_relation = Alias.new(@relation, :foo)
    end
    
    describe '#prefix_for' do
      it "delegates to the underlying relation" do
        @alias_relation.prefix_for(@relation[:id]).should == :users
      end
    end
    
    describe '#aliased_prefix_for' do
      it "returns the alias" do
        @alias_relation.aliased_prefix_for(@relation[:id]).should == :foo
        @alias_relation.aliased_prefix_for(:does_not_exist).should be_nil
      end
    end
  end
end