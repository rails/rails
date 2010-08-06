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

    describe 'Relation::Operable' do
      describe 'joins' do
        before do
          @predicate = @relation[:id].eq(@relation[:id])
        end

        describe '#join' do
          describe 'when given a relation' do
            it "manufactures an inner join operation between those two relations" do
              join = @relation.join(@relation).on(@predicate)
              join.relation1.should == @relation
              join.relation2.should == @relation
              join.predicates.should == [@predicate]
              join.should be_kind_of(InnerJoin)
            end
          end

          describe "when given a string" do
            it "manufactures a join operation with the string passed through" do
              arbitrary_string = "ASDF"

              join = @relation.join(arbitrary_string)
              join.relation1.should == @relation
              join.relation2.should == arbitrary_string
              join.predicates.should == []
              join.should be_kind_of StringJoin
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
            join = @relation.outer_join(@relation).on(@predicate)
            join.relation1.should == @relation
            join.relation2.should == @relation
            join.predicates.should == [@predicate]
            join.should be_kind_of OuterJoin
          end
        end
      end

      describe '#project' do
        it "manufactures a projection relation" do
          project = @relation.project(@attribute1, @attribute2)
          project.relation.should == @relation
          project.projections.should == [@attribute1, @attribute2]
          project.should be_kind_of Project
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
          where = @relation.where(@predicate)
          where.relation.should == @relation
          where.predicates.should == [@predicate]
          where.should be_kind_of Where
        end

        it "accepts arbitrary strings" do
          where = @relation.where("arbitrary")
          where.relation.should == @relation

          where.predicates.length.should == 1
          where.predicates.first.value.should == "arbitrary"

          where.should be_kind_of Where
        end

        describe 'when given a blank predicate' do
          it 'returns self' do
            @relation.where.should == @relation
          end
        end
      end

      describe '#order' do
        it "manufactures an order relation" do
          order = @relation.order(@attribute1, @attribute2)
          order.relation.should == @relation
          order.orderings.should == [@attribute1, @attribute2]
          order.should be_kind_of Order
        end

        describe 'when given a blank ordering' do
          it 'returns self' do
            @relation.order.should == @relation
          end
        end
      end

      describe '#take' do
        it "manufactures a take relation" do
          take = @relation.take(5)
          take.relation.should == @relation
          take.taken.should == 5
        end

        describe 'when given a blank number of items' do
          it 'raises error' do
            lambda { @relation.take }.should raise_exception
          end
        end
      end

      describe '#skip' do
        it "manufactures a skip relation" do
          skip = @relation.skip(4)
          skip.relation.should == @relation
          skip.skipped.should == 4
          skip.should be_kind_of Skip
        end

        describe 'when given a blank number of items' do
          it 'returns self' do
            @relation.skip.should == @relation
          end
        end
      end

      describe '#group' do
        it 'manufactures a group relation' do
          group = @relation.group(@attribute1, @attribute2)
          group.relation.should == @relation
          group.groupings.should == [@attribute1, @attribute2]
          group.should be_kind_of Group
          sql = group.to_sql
          sql.should =~ /GROUP BY/
        end

        describe 'when given blank groupings' do
          it 'returns self' do
            @relation.group.should == @relation
          end
        end
      end

      describe 'relation is writable' do
        describe '#delete' do
          it 'manufactures a deletion relation' do
            Session.start do |s|
              s.should_receive(:delete) do |delete|
                delete.relation.should == @relation
                delete.should be_kind_of Deletion
              end
              @relation.delete
            end
          end
        end

        describe '#insert' do
          it 'manufactures an insertion relation' do
            Session.start do |s|
              record = { @relation[:name] => Value.new('carl', @relation) }
              s.should_receive(:create) do |insert|
                insert.relation.should == @relation
                insert.record.should == record
                insert.should be_kind_of Insert
                insert
              end
              @relation.insert(record)
            end
          end
        end

        describe '#update' do
          it 'manufactures an update relation' do
            Session.start do |s|
              assignments = { @relation[:name] => Value.new('bob', @relation) }
              s.should_receive(:update) do |update|
                update.relation.should == @relation
                update.assignments.should == assignments
                update.should be_kind_of Update
                update
              end
              @relation.update(assignments)
            end
          end
        end
      end
    end

    describe 'is enumerable' do
      it "implements enumerable" do
        @relation.map { |value| value }.should ==
        @relation.session.read(@relation).map { |value| value }
      end
    end
  end
end
