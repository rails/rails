require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe RenameRelation do
  before do
    @relation = TableRelation.new(:foo)
    @renamed_relation = RenameRelation.new(@relation, @relation[:id] => :schmid)
  end

  describe '#initialize' do
    it "manufactures nested rename relations if multiple renames are provided" do
      RenameRelation.new(@relation, @relation[:id] => :humpty, @relation[:name] => :dumpty). \
        should == RenameRelation.new(RenameRelation.new(@relation, @relation[:id] => :humpty), @relation[:name] => :dumpty)
    end

    it "raises an exception if the alias provided is already used" do
      pending
    end
  end
    
  describe '==' do
    it "obtains if the relation, attribute, and alias are identical" do
      pending
    end
  end
  
  describe '#attributes' do
    it "manufactures a list of attributes with the renamed attribute aliased" do
      RenameRelation.new(@relation, @relation[:id] => :schmid).attributes.should ==
        (@relation.attributes - [@relation[:id]]) + [@relation[:id].alias(:schmid)]
    end
  end
  
  describe '[]' do
    it 'indexes attributes by alias' do
      @renamed_relation[:id].should be_nil
      @renamed_relation[:schmid].should == @relation[:id]
    end
  end
  
  describe '#schmattribute' do
    it "should be renamed" do
      pending
    end
  end
  
  describe '#qualify' do
    it "distributes over the relation and renames" do
      RenameRelation.new(@relation, @relation[:id] => :schmid).qualify. \
        should == RenameRelation.new(@relation.qualify, @relation[:id].qualify => :schmid)
    end
  end
  
  describe '#to_sql' do
    it 'manufactures sql aliasing the attribute' do
      @renamed_relation.to_s.should == SelectBuilder.new do
        select do
          column :foo, :name
          column :foo, :id, :schmid
        end
        from :foo
      end.to_s
    end
  end
end