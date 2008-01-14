require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Alias do
    before do
      @relation = Table.new(:users)
      @alias_relation = @relation.as(:foo)
    end
  
    describe '#name' do
      it 'returns the alias' do
        @alias_relation.name.should == :foo
      end
    end
  
    describe '#attributes' do
      it 'manufactures sql deleting a table relation' do
        @alias_relation.attributes.should == @relation.attributes.collect { |a| Attribute.new(@alias_relation, a.name) }
      end
    end
  
    describe '[]' do
      it 'manufactures attributes associated with the aliased relation' do
        @alias_relation[:id].relation.should == @alias_relation
        @alias_relation[:does_not_exist].should be_nil
      end
    end
  
    describe '#to_sql' do
      it "manufactures an aliased select query" do
        @alias_relation.to_sql.should be_like("""
          SELECT `foo`.`name`, `foo`.`id`
          FROM `users` AS `foo`
        """)
      end
    end
  end
end