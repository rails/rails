require File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'spec_helper')

module Arel
  describe Deletion do
    before do
      @relation = Table.new(:users)
    end
  end
end