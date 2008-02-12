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
      end
    end
  
    describe '[]' do
      describe 'when given a', Symbol do
        it 'indexes attributes by rename if the symbol names an attribute within the relation' do
          @renamed_relation[:id].should be_nil
          @renamed_relation[:schmid].should == @relation1[:id].as(:schmid).substitute(@renamed_relation)
          @renamed_relation[:does_not_exist].should be_nil
        end
      end
      
      describe 'when given an', Attribute do
        it 'manufactures a substituted and renamed attribute if the attribute is within the relation' do
          @renamed_relation[@relation1[:id]].should == @relation1[:id].as(:schmid).substitute(@renamed_relation)
          @renamed_relation[@relation1[:name]].should == @relation1[:name].substitute(@renamed_relation)
          @renamed_relation[@renamed_relation[:name]].should == @renamed_relation[:name]
          @renamed_relation[@relation2[:id]].should be_nil
        end
      end

      describe 'when given an', Expression do
        it "manufactures a substituted and renamed expression if the expression is within the relation" do
          pending
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
            @renamed_renamed_relation[:flid].should == @renamed_relation[:schmid].as(:flid).substitute(@renamed_renamed_relation)
          end
        end
        
        describe 'when given an', Attribute do
          it "manufactures a substituted and renamed attribute if the attribute is within the relation -- even if the provided attribute derived" do
            @renamed_renamed_relation[@renamed_relation[:schmid]].should == @renamed_relation[:schmid].as(:flid).substitute(@renamed_renamed_relation)
            @renamed_renamed_relation[@relation1[:id]].should == @renamed_relation[:schmid].as(:flid).substitute(@renamed_renamed_relation)
          end
        end
        
        describe 'when given an', Expression do
          before do
            @expression = @relation1[:id].count
            @aggregation = Aggregation.new(@relation1, :expressions => [@expression])
            @renamed_relation = Rename.new(@aggregation, @expression => :cnt)
          end
          
          it "manufactures a substituted and renamed expression if the expression is within the relation" do
            @renamed_relation[@expression].should == @aggregation[@expression].as(:cnt).substitute(@renamed_relation)
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
          SELECT `users`.`id` AS 'schmid', `users`.`name`
          FROM `users`
        """)
      end
    end
  end
end