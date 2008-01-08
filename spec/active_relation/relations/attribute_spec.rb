require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe Attribute do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
  end
  
  describe '#alias' do
    it "manufactures an aliased attributed" do
      pending
    end
    
    it "should be renamed to #alias!" do
      pending
      @relation1.alias
    end
  end
  
  describe '#qualified_name' do
    it "manufactures an attribute name prefixed with the relation's name" do
      @relation1[:id].qualified_name.should == 'foo.id'
    end
  end
  
  describe '#qualify' do
    it "manufactures an attribute aliased with that attributes qualified name" do
      @relation1[:id].qualify == @relation1[:id].qualify
    end
  end
  
  describe '#eql?' do
    it "obtains if the relation and attribute name are identical" do
      Attribute.new(@relation1, :name).should be_eql(Attribute.new(@relation1, :name))
      Attribute.new(@relation1, :name).should_not be_eql(Attribute.new(@relation1, :another_name))
      Attribute.new(@relation1, :name).should_not be_eql(Attribute.new(@relation2, :name))
    end
  end
  
  describe 'predications' do
    before do
      @attribute1 = Attribute.new(@relation1, :name)
      @attribute2 = Attribute.new(@relation2, :name)
    end
    
    describe '==' do
      it "manufactures an equality predicate" do
        (@attribute1 == @attribute2).should == EqualityPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe '<' do
      it "manufactures a less-than predicate" do
        (@attribute1 < @attribute2).should == LessThanPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe '<=' do
      it "manufactures a less-than or equal-to predicate" do
        (@attribute1 <= @attribute2).should == LessThanOrEqualToPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe '>' do
      it "manufactures a greater-than predicate" do
        (@attribute1 > @attribute2).should == GreaterThanPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe '>=' do
      it "manufactures a greater-than or equal to predicate" do
        (@attribute1 >= @attribute2).should == GreaterThanOrEqualToPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe '=~' do
      it "manufactures a match predicate" do
        (@attribute1 =~ /.*/).should == MatchPredicate.new(@attribute1, @attribute2)
      end
    end
  end
  
  describe '#to_sql' do
    it "manufactures a column" do
      Attribute.new(@relation1, :name, :alias).to_sql.should == SelectsBuilder.new do
        column :foo, :name, :alias
      end
    end
  end
end
