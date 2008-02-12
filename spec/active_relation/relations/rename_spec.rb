require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Rename do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @renamed_relation = Rename.new(@relation1, @relation1[:id] => :schmid)
    end

    describe '#initialize' do
      it "manufactures nested rename relations if multiple renames are provided" do
        Rename.new(@relation1, @relation1[:id] => :humpty, @relation1[:name] => :dumpty). \
          should == Rename.new(Rename.new(@relation1, @relation1[:name] => :dumpty), @relation1[:id] => :humpty)
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
        @renamed_relation.attributes.should include(@renamed_relation[:schmid])
        @renamed_relation.should have(@relation1.attributes.size).attributes
        pending "this should be more rigorous"
      end
    end
  
    describe '#qualify' do
      it "distributes over the relation and renames" do
        Rename.new(@relation1, @relation1[:id] => :schmid).qualify. \
          should == Rename.new(@relation1.qualify, @relation1[:id].qualify => :schmid)
      end
    end
  
    describe '#to_sql' do
      it 'manufactures sql renaming the attribute' do
        @renamed_relation.to_sql.should be_like("""
          SELECT `users`.`id` AS 'schmid', `users`.`name`
          FROM `users`
        """)
      end
    end
  end
end