require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
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
          
          describe "when given something blank" do
            it "returns self" do
              @relation.join.should == @relation
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
        
        describe "when given blank attributes" do
          it "returns self" do
            @relation.project.should == @relation
          end
        end
      end

      describe '#alias' do
        it "manufactures an alias relation" do
          @relation.alias.relation.should == Alias.new(@relation).relation
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

        describe 'when given a blank predicate' do
          it 'returns self' do
            @relation.select.should == @relation
          end
        end
      end
  
      describe '#order' do
        it "manufactures an order relation" do
          @relation.order(@attribute1, @attribute2).should == Order.new(@relation, @attribute1, @attribute2)
        end
        
        describe 'when given a blank ordering' do
          it 'returns self' do
            @relation.order.should == @relation
          end
        end
      end
      
      describe '#take' do
        it "manufactures a take relation" do
          @relation.take(5).should == Take.new(@relation, 5)
        end
        
        describe 'when given a blank number of items' do
          it 'returns self' do
            @relation.take.should == @relation
          end
        end
      end
      
      describe '#skip' do
        it "manufactures a skip relation" do
          @relation.skip(4).should == Skip.new(@relation, 4)
        end
        
        describe 'when given a blank number of items' do
          it 'returns self' do
            @relation.skip.should == @relation
          end
        end
      end

      describe '#group' do
        it 'manufactures a group relation' do
          @relation.group(@attribute1, @attribute2).should == Grouping.new(@relation, @attribute1, @attribute2)
        end
        
        describe 'when given blank groupings' do
          it 'returns self' do
            @relation.group.should == @relation
          end
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
      it "implements enumerable" do
        @relation.collect.should == @relation.session.read(@relation)
        @relation.first.should == @relation.session.read(@relation).first
      end
    end
    
    describe '#call' do
      it 'executes a select_all on the connection' do
        mock(connection = Object.new).execute(@relation.to_sql) { [] }
        @relation.call(connection)
      end
    end
  end
end