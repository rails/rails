require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Relation do
    before do
      @relation = Table.new(:users)
      @attribute1 = @relation[:id]
      @attribute2 = @relation[:name]
    end
  
    describe '[]' do
      describe 'when given an', Attribute do
        it "return the attribute congruent to the provided attribute" do
          @relation[@attribute1].should == @attribute1
        end
      end
      
      describe 'when given a', Symbol, String do
        it "returns the attribute with the same name, if it exists" do
          @relation[:id].should == @attribute1
          @relation['id'].should == @attribute1
          @relation[:does_not_exist].should be_nil
        end
      end
    end
  
    describe Relation::Externalizable do
      describe '#aggregation?' do
        it "returns false" do
          @relation.should_not be_aggregation
        end
      end

      describe '#alias?' do
        it "returns false" do
          @relation.should_not be_alias
        end
      end
    end
    
    describe Relation::Operations do
      describe 'joins' do
        before do
          @predicate = @relation[:id].eq(@relation[:id])
        end
      
        describe '#join' do
          describe 'when given a relation' do
            it "manufactures an inner join operation between those two relations" do
              @relation.join(@relation).on(@predicate). \
                should == Join.new("INNER JOIN", @relation, @relation, @predicate)
            end
          end
          
          describe "when given a string" do
            it "manufactures a join operation with the string passed through" do
              @relation.join(arbitrary_string = "ASDF").should == Join.new(arbitrary_string, @relation) 
            end
          end
        end

        describe '#outer_join' do
          it "manufactures a left outer join operation between those two relations" do
            @relation.outer_join(@relation).on(@predicate). \
              should == Join.new("LEFT OUTER JOIN", @relation, @relation, @predicate)
          end
        end
      end

      describe '#project' do
        it "manufactures a projection relation" do
          @relation.project(@attribute1, @attribute2). \
            should == Projection.new(@relation, @attribute1, @attribute2)
        end
      end

      describe '#as' do
        it "manufactures an alias relation" do
          @relation.as(:paul).should == Alias.new(@relation, :paul)
        end
      end
  
      describe '#rename' do
        it "manufactures a rename relation" do
          @relation.rename(@attribute1, :users).should == Rename.new(@relation, @attribute1 => :users)
        end
      end
  
      describe '#select' do
        before do
          @predicate = Equality.new(@attribute1, @attribute2)
        end
    
        it "manufactures a selection relation" do
          @relation.select(@predicate).should == Selection.new(@relation, @predicate)
        end
    
        it "accepts arbitrary strings" do
          @relation.select("arbitrary").should == Selection.new(@relation, "arbitrary")
        end
      end
  
      describe '#order' do
        it "manufactures an order relation" do
          @relation.order(@attribute1, @attribute2).should == Order.new(@relation, @attribute1, @attribute2)
        end
      end
      
      describe '#take' do
        it "manufactures a take relation" do
          @relation.take(5).should == Take.new(@relation, 5)
        end
      end
      
      describe '#skip' do
        it "manufactures a skip relation" do
          @relation.skip(4).should == Skip.new(@relation, 4)
        end
      end
      
      describe '#call' do
        it 'executes a select_all on the connection' do
          mock(connection = Object.new).select_all(@relation.to_sql)
          @relation.call(connection)
        end
      end
      
      
      describe '#aggregate' do
        before do
          @expression1 = @attribute1.sum
          @expression2 = @attribute2.sum
        end
        
        it 'manufactures a group relation' do
          @relation.aggregate(@expression1, @expression2).group(@attribute1, @attribute2). \
            should == Aggregation.new(@relation,
                        :expressions => [@expression1, @expression2],
                        :groupings => [@attribute1, @attribute2]
                      )
        end
      end
      
      describe Relation::Operations::Writes do
        describe '#delete' do
          it 'manufactures a deletion relation' do
            Session.start do
              mock(Session.new).delete(Deletion.new(@relation))
              @relation.delete.should == @relation
            end
          end
        end

        describe '#insert' do
          it 'manufactures an insertion relation' do
            Session.start do
              record = {@relation[:name] => 'carl'}
              mock(Session.new).create(Insertion.new(@relation, record))
              @relation.insert(record).should == @relation
            end
          end
        end

        describe '#update' do
          it 'manufactures an update relation' do
            Session.start do
              assignments = {@relation[:name] => Value.new('bob', @relation)}
              mock(Session.new).update(Update.new(@relation, assignments))
              @relation.update(assignments).should == @relation
            end
          end
        end
      end
    end
      
    describe Relation::Enumerable do
      it "is enumerable" do
        pending "I don't like this mock-based test"
        data = [1,2,3]
        mock.instance_of(Session).read(anything) { data }
        @relation.collect.should == data
        @relation.first.should == data.first
      end
    end
  end
end