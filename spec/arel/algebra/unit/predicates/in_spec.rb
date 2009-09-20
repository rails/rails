require 'spec_helper'

module Arel
  describe In do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end
  end
end
