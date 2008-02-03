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
        @renamed_relation.attributes.should include(Attribute.new(@renamed_relation, :id, :schmid))
        @renamed_relation.should have(@relation1.attributes.size).attributes
      end
    end
  
    describe '[]' do
      describe 'when given a', Symbol do
        it 'indexes attributes by rename if the symbol names an attribute within the relation' do
          @renamed_relation[:id].should be_nil
          @renamed_relation[:schmid].should == Attribute.new(@renamed_relation, :id, :schmid)
          @renamed_relation[:does_not_exist].should be_nil
        end
      end
      
      describe 'when given an', Attribute do
        it 'manufactures a substituted and renamed attribute if the attribute is within the relation' do
          @renamed_relation[Attribute.new(@relation1, :id)].should == Attribute.new(@renamed_relation, :id, :schmid)
          @renamed_relation[Attribute.new(@relation1, :name)].should == Attribute.new(@renamed_relation, :name)
          @renamed_relation[Attribute.new(@renamed_relation, :name)].should == Attribute.new(@renamed_relation, :name)
          @renamed_relation[Attribute.new(@relation2, :id)].should be_nil
        end
      end

      describe 'when given an', Expression do
        it "manufactures a substituted and renamed expression if the expression is within the relation" do
        end
      end
      
      describe 'when the rename is constructed with a derived attribute' do
        before do
          @renamed_renamed_relation = Rename.new(@renamed_relation, @relation1[:id] => :flid)
        end
        
        describe 'when given a', Symbol do
          it 'manufactures a substituted and renamed attribute if the attribute is within the relation' do
            @renamed_renamed_relation[:id].should be_nil
            @renamed_renamed_relation[:schmid].should be_nil
            @renamed_renamed_relation[:flid].should == Attribute.new(@renamed_renamed_relation, :id, :flid)
          end
        end
        
        describe 'when given an', Attribute do
          it "manufactures a substituted and renamed attribute if the attribute is within the relation -- even if the provided attribute derived" do
            @renamed_renamed_relation[Attribute.new(@renamed_relation, :id, :schmid)].should == Attribute.new(@renamed_renamed_relation, :id, :flid)
            @renamed_renamed_relation[Attribute.new(@relation1, :id)].should == Attribute.new(@renamed_renamed_relation, :id, :flid)
          end
        end
        
        describe 'when given an', Expression do
          it "manufactures a substituted and renamed expression if the expression is within the relation" do
            renamed_relation = Rename.new(Aggregation.new(@relation1, :expressions => [@relation1[:id].count]), @relation1[:id].count => :cnt)
            renamed_relation[@relation1[:id].count].should == @relation1[:id].count.as(:cnt).substitute(renamed_relation)
            renamed_relation.attributes.should == [@relation1[:id].count.as(:cnt).substitute(renamed_relation)]
          end
        end
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
          SELECT `foo`.`name`, `foo`.`id` AS 'schmid'
          FROM `foo`
        """)
      end
    end
  end
end