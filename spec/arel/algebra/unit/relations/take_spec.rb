require 'spec_helper'

module Arel
  describe Take do
    before do
      @relation = Table.new(:users)
      @taken = 4
    end
  end
end
