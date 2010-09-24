require 'spec_helper'

module Arel
  describe 'Attributes' do
    describe 'for' do
      it 'returns the correct constant for strings' do
        [:string, :text, :binary].each do |type|
          column = Struct.new(:type).new type
          Attributes.for(column).should == Attributes::String
        end
      end

      it 'returns the correct constant for ints' do
        column = Struct.new(:type).new :integer
        Attributes.for(column).should == Attributes::Integer
      end

      it 'returns the correct constant for floats' do
        column = Struct.new(:type).new :float
        Attributes.for(column).should == Attributes::Float
      end

      it 'returns the correct constant for decimals' do
        column = Struct.new(:type).new :decimal
        Attributes.for(column).should == Attributes::Decimal
      end

      it 'returns the correct constant for boolean' do
        column = Struct.new(:type).new :boolean
        Attributes.for(column).should == Attributes::Boolean
      end

      it 'returns the correct constant for time' do
        [:date, :datetime, :timestamp, :time].each do |type|
          column = Struct.new(:type).new type
          Attributes.for(column).should == Attributes::Time
        end
      end
    end
  end
end
