require 'cases/helper'
require 'models/post'
require 'models/author'

module ActiveRecord
  module Associations
    class AssociationScopeTest < ActiveRecord::TestCase
      test 'does not duplicate conditions' do
        scope = AssociationScope.scope(Author.new.association(:welcome_posts),
                                        Author.connection)
        wheres = scope.where_values.map(&:right)
        assert_equal wheres.uniq, wheres
      end
    end
  end
end
