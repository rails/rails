# frozen_string_literal: true
require 'helper'

module Arel
  module Nodes
    describe 'BindParam' do
      it 'is equal to other bind params' do
        BindParam.new.must_equal(BindParam.new)
      end

      it 'is not equal to other nodes' do
        BindParam.new.wont_equal(Node.new)
      end
    end
  end
end
