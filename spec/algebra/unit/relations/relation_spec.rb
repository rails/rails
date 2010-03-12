require 'spec_helper'

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
        it "returns the attribute with the same name" do
          check @relation[:id].should == @attribute1
          check @relation['id'].should == @attribute1
        end
      end
    end

    describe Relation::Operable do
      describe 'joins' do
        before do
          @predicate = @relation[:id].eq(@relation[:id])
        end

        describe '#join' do
          describe 'when given a relation' do
            it "manufactures an inner join operation between those two relations" do
              @relation.join(@relation).on(@predicate). \
                should == InnerJoin.new(@relation, @relation, @predicate)
            end
          end

          describe "when given a string" do
            it "manufactures a join operation with the string passed through" do
              @relation.join(arbitrary_string = "ASDF").should == StringJoin.new(@relation, arbitrary_string)
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
              should == OuterJoin.new(@relation, @relation, @predicate)
          end
        end
      end

      describe '#project' do
        it "manufactures a projection relation" do
          @relation.project(@attribute1, @attribute2). \
            should == Project.new(@relation, @attribute1, @attribute2)
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

      describe '#where' do
        before do
          @predicate = Predicates::Equality.new(@attribute1, @attribute2)
        end

        it "manufactures a where relation" do
          @relation.where(@predicate).should == Where.new(@relation, @predicate)
        end

        it "accepts arbitrary strings" do
          @relation.where("arbitrary").should == Where.new(@relation, "arbitrary")
        end

        describe 'when given a blank predicate' do
          it 'returns self' do
            @relation.where.should == @relation
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
          @relation.group(@attribute1, @attribute2).should == Group.new(@relation, @attribute1, @attribute2)
        end

        describe 'when given blank groupings' do
          it 'returns self' do
            @relation.group.should == @relation
          end
        end
      end

      describe Relation::Operable::Writable do
        describe '#delete' do
          it 'manufactures a deletion relation' do
            Session.start do
              Session.new.should_receive(:delete).with(Deletion.new(@relation))
              @relation.delete
            end
          end
        end

        describe '#insert' do
          it 'manufactures an insertion relation' do
            Session.start do
              record = { @relation[:name] => 'carl' }
              Session.new.should_receive(:create).with(Insert.new(@relation, record))
              @relation.insert(record)
            end
          end
        end

        describe '#update' do
          it 'manufactures an update relation' do
            Session.start do
              assignments = { @relation[:name] => Value.new('bob', @relation) }
              Session.new.should_receive(:update).with(Update.new(@relation, assignments))
              @relation.update(assignments)
            end
          end
        end
      end
    end

    describe Relation::Enumerable do
      it "implements enumerable" do
        @relation.map { |value| value }.should ==
        @relation.session.read(@relation).map { |value| value }
      end
    end
  end
end
