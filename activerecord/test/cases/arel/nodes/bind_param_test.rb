# frozen_string_literal: true
require_relative '../helper'

module Arel
  module Nodes
    describe 'BindParam' do
      it 'is equal to other bind params with the same value' do
        BindParam.new(1).must_equal(BindParam.new(1))
        BindParam.new("foo").must_equal(BindParam.new("foo"))
      end

      it 'is not equal to other nodes' do
        BindParam.new(nil).wont_equal(Node.new)
      end

      it 'is not equal to bind params with different values' do
        BindParam.new(1).wont_equal(BindParam.new(2))
      end
    end
  end
end
