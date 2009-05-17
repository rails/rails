require File.join(File.dirname(__FILE__), '..', '..', '..', '..', '..', 'spec_helper')

module Arel
  describe Array do
    before do
      @relation = Array.new([
        [1, 'duck' ],
        [2, 'duck' ],
        [3, 'goose']
      ], [:id, :name])
    end

    describe '#attributes' do
      it 'manufactures attributes corresponding to the names given on construction' do
        @relation.attributes.should == [
          Attribute.new(@relation, :id),
          Attribute.new(@relation, :name)
        ]
      end
    end

    describe '#call' do
      it "manufactures an array of hashes of attributes to values" do
        @relation.call.should == [
          Row.new(@relation, [1, 'duck']),
          Row.new(@relation, [2, 'duck']),
          Row.new(@relation, [3, 'goose'])
        ]
      end
      
      describe 'where' do
        xit 'filters the relation with the provided predicate' do
          @relation                       \
            .where(@relation[:id].lt(3))  \
          .let do |relation|
            relation.call.should == [
              Row.new(relation, [1, 'duck']),
              Row.new(relation, [2, 'duck']),
            ]
          end
        end
        
        it 'filters the relation with the provided predicate' do
          @relation                       \
            .where(@relation[:id].gt(1))  \
            .where(@relation[:id].lt(3))  \
          .let do |relation|
            relation.call.should == [
              Row.new(relation, [2, 'duck'])
            ]
          end
        end
      end
      
      describe 'group' do
        xit 'sorts the relation with the provided ordering' do
        end
      end
      
      describe 'order' do
        it 'sorts the relation with the provided ordering' do
          @relation                     \
            .order(@relation[:id].desc) \
          .let do |relation|
            relation.call.should == [
              Row.new(relation, [3, 'goose']),
              Row.new(relation, [2, 'duck']),
              Row.new(relation, [1, 'duck'])
            ]
          end
        end
      end
      
      describe 'project' do
        it 'projects' do
          @relation                   \
            .project(@relation[:id])  \
          .let do |relation|
            relation.call.should == [
              Row.new(relation, [1]),
              Row.new(relation, [2]),
              Row.new(relation, [3])
            ]
          end
        end
      end
      
      describe 'skip' do
        it 'slices' do
          @relation   \
            .skip(1)  \
          .let do |relation|
            relation.call.should == [
              Row.new(relation, [2, 'duck']),
              Row.new(relation, [3, 'goose']),
            ]
          end
        end
      end
      
      describe 'take' do
        it 'dices' do
          @relation   \
            .take(2)  \
          .let do |relation|
            relation.call.should == [
              Row.new(relation, [1, 'duck']),
              Row.new(relation, [2, 'duck']),
            ]
          end
        end
      end
      
      describe 'join' do
      end
    end
  end
end