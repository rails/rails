require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Table do
    before do
      @relation = Table.new(:users)
    end
  
    describe '[]' do
      describe 'when given a', Symbol do
        it "manufactures an attribute if the symbol names an attribute within the relation" do
          @relation[:id].should == Attribute.new(@relation, :id)
          @relation[:does_not_exist].should be_nil
        end
      end

      describe 'when given an', Attribute do
        it "returns the attribute if the attribute is within the relation" do
          @relation[@relation[:id]].should == @relation[:id]
        end
        
        it "returns nil if the attribtue is not within the relation" do
          another_relation = Table.new(:photos)
          @relation[another_relation[:id]].should be_nil
        end
      end
      
      describe 'when given an', Expression do
        before do
          @expression = @relation[:id].count
        end
        
        it "returns the Expression if the Expression is within the relation" do
          @relation[@expression].should be_nil
        end
      end
    end
    
    describe '#to_sql' do
      it "manufactures a simple select query" do
        @relation.to_sql.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
        ")
      end
    end
    
    describe '#column_for' do
      it "returns the column corresponding to the attribute" do
        @relation.column_for(@relation[:id]).should == @relation.columns.detect { |c| c.name == 'id' }
      end
    end
    
    describe '#prefix_for' do
      it "returns the table name if the relation contains the attribute" do
        @relation.prefix_for(@relation[:id]).should == 'users'
        @relation.prefix_for(:does_not_exist).should be_nil
      end
    end
    
    describe '#attributes' do
      it 'manufactures attributes corresponding to columns in the table' do
        @relation.attributes.should == [
          Attribute.new(@relation, :id),
          Attribute.new(@relation, :name)
        ]
      end
      
      describe '#reset' do
        it "reloads columns from the database" do
          lambda { stub(@relation.engine).columns { [] } }.should_not change { @relation.attributes }
          lambda { @relation.reset }.should change { @relation.attributes }
        end
      end
    end
  
    describe 'hashing' do
      it "implements hash equality" do
        Table.new(:users).should hash_the_same_as(Table.new(:users))
        Table.new(:users).should_not hash_the_same_as(Table.new(:photos))
      end
    end
    
    describe '#engine' do
      it "defaults to global engine" do
        Table.engine = engine = Engine.new
        Table.new(:users).engine.should == engine
      end
      
      it "can be specified" do
        Table.new(:users, engine = Engine.new).engine.should == engine
      end
    end
  end
end