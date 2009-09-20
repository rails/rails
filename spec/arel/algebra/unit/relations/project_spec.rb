require 'spec_helper'

module Arel
  describe Project do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe '#attributes' do
      before do
        @projection = Project.new(@relation, @attribute)
      end

      it "manufactures attributes associated with the projection relation" do
        @projection.attributes.should == [@attribute].collect { |a| a.bind(@projection) }
      end
    end

    describe '#externalizable?' do
      describe 'when the projections are attributes' do
        it 'returns false' do
          Project.new(@relation, @attribute).should_not be_externalizable
        end
      end

      describe 'when the projections include an aggregation' do
        it "obtains" do
          Project.new(@relation, @attribute.sum).should be_externalizable
        end
      end
    end
  end
end
