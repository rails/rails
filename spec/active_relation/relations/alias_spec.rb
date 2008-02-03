require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Alias do
    before do
      @relation = Table.new(:users)
      @alias_relation = @relation.as(:foo)
    end
  end
end