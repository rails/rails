require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

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
          { @relation[:id] => 1, @relation[:name] => 'duck'  },
          { @relation[:id] => 2, @relation[:name] => 'duck'  },
          { @relation[:id] => 3, @relation[:name] => 'goose' }
        ]
      end
      
      describe 'where' do
        it 'filters the relation with the provided predicate' do
          @relation.where(@relation[:id].lt(3)).call.should == [
            { @relation[:id] => 1, @relation[:name] => 'duck' },
            { @relation[:id] => 2, @relation[:name] => 'duck' }
          ]
        end
      end
      
      describe 'group' do
        it 'sorts the relation with the provided ordering' do
        end
      end
      
      describe 'order' do
        it 'sorts the relation with the provided ordering' do
          @relation.order(@relation[:id].desc).call.should == [
            { @relation[:id] => 3, @relation[:name] => 'goose' },
            { @relation[:id] => 2, @relation[:name] => 'duck'  },
            { @relation[:id] => 1, @relation[:name] => 'duck'  }
          ]
        end
      end
      
      describe 'project' do
        it 'projects' do
          @relation.project(@relation[:id]).call.should == [
            { @relation[:id] => 1 },
            { @relation[:id] => 2 },
            { @relation[:id] => 3 }
          ]
        end
      end
      
      describe 'skip' do
        it 'slices' do
          @relation.skip(1).call.should == [
            { @relation[:id] => 2, @relation[:name] => 'duck'  },
            { @relation[:id] => 3, @relation[:name] => 'goose' }
          ]
        end
      end
      
      describe 'take' do
        it 'dices' do
          @relation.take(2).call.should == [
            { @relation[:id] => 1, @relation[:name] => 'duck' },
            { @relation[:id] => 2, @relation[:name] => 'duck' }
          ]
        end
      end
      
      describe 'join' do
      end
    end
  end
end