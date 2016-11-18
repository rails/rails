require "cases/helper"
require "models/post"
require "models/author"

module ActiveRecord
  module Associations
    class AssociationScopeTest < ActiveRecord::TestCase
      test "does not duplicate conditions" do
        scope = AssociationScope.scope(Author.new.association(:welcome_posts),
                                        Author.connection)
        binds = scope.where_clause.binds.map(&:value)
        assert_equal binds.uniq, binds
      end
    end
  end
end
