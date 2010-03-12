require 'spec_helper'

module Arel
  module Predicates
    describe In do
      before do
        @relation = Table.new(:users)
        @attribute = @relation[:id]
      end
    end
  end
end
