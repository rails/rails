require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Rename do
    before do
      @relation = Table.new(:foo)
      @renamed_relation = Rename.new(@relation, @relation[:id] => :schmid)
    end

    describe '#initialize' do
      it "manufactures nested rename relations if multiple renames are provided" do
        Rename.new(@relation, @relation[:id] => :humpty, @relation[:name] => :dumpty). \
          should == Rename.new(Rename.new(@relation, @relation[:id] => :humpty), @relation[:name] => :dumpty)
      end

      it "raises an exception if the rename provided is already used" do
        pending
      end
    end
    
    describe '==' do
      it "obtains if the relation, attribute, and rename are identical" do
        pending
      end
    end
  
    describe '#attributes' do
      it "manufactures a list of attributes with the renamed attribute renameed" do
        Rename.new(@relation, @relation[:id] => :schmid).attributes.should ==
          (@relation.attributes - [@relation[:id]]) + [@relation[:id].as(:schmid)]
      end
    end
  
    describe '[]' do
      it 'indexes attributes by rename' do
        @renamed_relation[:id].should be_nil
        @renamed_relation[:schmid].should == @relation[:id].as(:schmid)
      end
    end
  
    describe '#qualify' do
      it "distributes over the relation and renames" do
        Rename.new(@relation, @relation[:id] => :schmid).qualify. \
          should == Rename.new(@relation.qualify, @relation[:id].qualify => :schmid)
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