require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Rename do
    before do
      @relation = Table.new(:users)
    end

    describe '#initialize' do
      it "manufactures nested rename relations if multiple renames are provided" do
        Rename.new(@relation, @relation[:id] => :humpty, @relation[:name] => :dumpty). \
          should == Rename.new(Rename.new(@relation, @relation[:name] => :dumpty), @relation[:id] => :humpty)
      end
    end
    
    describe '==' do
      before do
        @another_relation = Table.new(:photos)
      end
      
      it "obtains if the relation, attribute, and rename are identical" do
        Rename.new(@relation, @relation[:id] => :humpty).should == Rename.new(@relation, @relation[:id] => :humpty)
        Rename.new(@relation, @relation[:id] => :humpty).should_not == Rename.new(@relation, @relation[:id] => :dumpty)
        Rename.new(@relation, @relation[:id] => :humpty).should_not == Rename.new(@another_relation, @relation[:id] => :humpty)
      end
    end
  
    describe '#attributes' do
      before do
        @renamed_relation = Rename.new(@relation, @relation[:id] => :schmid)
      end
      
      it "manufactures a list of attributes with the renamed attribute renameed" do
        @renamed_relation.attributes.should include(@relation[:id].as(:schmid).bind(@renamed_relation))
        @renamed_relation.attributes.should_not include(@relation[:id].bind(@renamed_relation))
        @renamed_relation.attributes.should include(@relation[:name].bind(@renamed_relation))
        @renamed_relation.should have(@relation.attributes.size).attributes
      end
    end

    describe '#to_sql' do
      it 'manufactures sql renaming the attribute' do
        Rename.new(@relation, @relation[:id] => :schmid).to_sql.should be_like("
          SELECT `users`.`id` AS 'schmid', `users`.`name`
          FROM `users`
        ")
      end
    end
  end
end