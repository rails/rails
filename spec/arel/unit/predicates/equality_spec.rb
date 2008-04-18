require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Equality do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @attribute1 = @relation1[:id]
      @attribute2 = @relation2[:user_id]
    end
  
    describe '==' do 
      it "obtains if attribute1 and attribute2 are identical" do
        Equality.new(@attribute1, @attribute2).should == Equality.new(@attribute1, @attribute2)
        Equality.new(@attribute1, @attribute2).should_not == Equality.new(@attribute1, @attribute1)
      end
    
      it "obtains if the concrete type of the predicates are identical" do
        Equality.new(@attribute1, @attribute2).should_not == Binary.new(@attribute1, @attribute2)
      end
    
      it "is commutative on the attributes" do
        Equality.new(@attribute1, @attribute2).should == Equality.new(@attribute2, @attribute1)
      end
    end
    
    describe '#to_sql' do
      describe 'when relating to a non-nil value' do
        it "manufactures an equality predicate" do
          Equality.new(@attribute1, @attribute2).to_sql.should be_like("
            `users`.`id` = `photos`.`user_id`
          ")
        end
      end
      
      describe 'when relation to a nil value' do
        before do
          @nil = nil
        end
        
        it "manufactures an is null predicate" do
          Equality.new(@attribute1, @nil).to_sql.should be_like("
            `users`.`id` IS NULL
          ")
        end
      end
    end
  end
end