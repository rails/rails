require 'spec_helper'

module Arel
  describe Skip do
    before do
      @relation = Table.new(:users)
      @skipped = 4
    end
  end
end
