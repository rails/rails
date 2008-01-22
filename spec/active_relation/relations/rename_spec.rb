require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Rename do
    before do
      @relation1 = Table.new(:foo)
      @relation2 = Table.new(:bar)
      @renamed_relation = Rename.new(@relation1, @relation1[:id] => :schmid)
    end

    describe '#initialize' do
      it "manufactures nested rename relations if multiple renames are provided" do
        Rename.new(@relation1, @relation1[:id] => :humpty, @relation1[:name] => :dumpty). \
          should == Rename.new(Rename.new(@relation1, @relation1[:id] => :humpty), @relation1[:name] => :dumpty)
      end
    end
    
    describe '==' do
      it "obtains if the relation, attribute, and rename are identical" do
        Rename.new(@relation1, @relation1[:id] => :humpty).should == Rename.new(@relation1, @relation1[:id] => :humpty)
        Rename.new(@relation1, @relation1[:id] => :humpty).should_not == Rename.new(@relation1, @relation1[:id] => :dumpty)
        Rename.new(@relation1, @relation1[:id] => :humpty).should_not == Rename.new(@relation2, @relation2[:id] => :humpty)
      end
    end
  
    describe '#attributes' do
      it "manufactures a list of attributes with the renamed attribute renameed" do
        Rename.new(@relation1, @relation1[:id] => :schmid).attributes.should ==
          (@relation1.attributes - [@relation1[:id]]) + [@relation1[:id].as(:schmid)]
      end
    end
  
    describe '[]' do
      it 'indexes attributes by rename' do
        @renamed_relation[:id].should be_nil
        @renamed_relation[:schmid].should == @relation1[:id].as(:schmid)
      end
    end
  
    describe '#qualify' do
      it "distributes over the relation and renames" do
        Rename.new(@relation1, @relation1[:id] => :schmid).qualify. \
          should == Rename.new(@relation1.qualify, @relation1[:id].qualify => :schmid)
      end
    end
  
    describe '#to_sql' do
      it 'manufactures sql renameing the attribute' do
        @renamed_relation.to_sql.should be_like("""
          SELECT `foo`.`name`, `foo`.`id` AS 'schmid'
          FROM `foo`
        """)
      end
    end
  end
end