require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Table do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
    end
  
    describe '[]' do
      describe 'when given a', Symbol do
        it "manufactures an attribute if the symbol names an attribute within the relation" do
          @relation1[:id].should == Attribute.new(@relation1, :id)
          @relation1[:does_not_exist].should be_nil
        end
      end

      describe 'when given an', Attribute do
        it "returns the attribute if the attribute is within the relation" do
          @relation1[@relation1[:id]].should == @relation1[:id]
          @relation1[@relation2[:id]].should be_nil
        end
      end
      
      describe 'when given an', Expression do
        before do
          @expression = Expression.new(Attribute.new(@relation1, :id), "COUNT")
        end
        
        it "returns the Expression if the Expression is within the relation" do
          @relation1[@expression].should be_nil
        end
      end
    end
    
    describe '#to_sql' do
      it "manufactures a simple select query" do
        @relation1.to_sql.should be_like("""
          SELECT `users`.`name`, `users`.`id`
          FROM `users`
        """)
      end
    end
    
    describe '#prefix_for' do
      it "always returns the table name" do
        @relation1.prefix_for(Attribute.new(@relation1, :id)).should == :users
      end
    end
  
    describe '#attributes' do
      it 'manufactures attributes corresponding to columns in the table' do
        @relation1.attributes.should == [
          Attribute.new(@relation1, :name),
          Attribute.new(@relation1, :id)
        ]
      end
    end
  
    describe '#qualify' do
      it 'manufactures a rename relation with all attribute names qualified' do
        @relation1.qualify.should == Rename.new(@relation1, @relation1[:id] => 'users.id', @relation1[:name] => 'users.name')
      end
    end
  end
end