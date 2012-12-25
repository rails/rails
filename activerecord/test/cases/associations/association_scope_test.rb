require 'cases/helper'
require 'models/post'
require 'models/author'

module ActiveRecord
  module Associations
    class AssociationScopeTest < ActiveRecord::TestCase
      test 'does not duplicate conditions' do
        association_scope = AssociationScope.new(Author.new.association(:welcome_posts))
        wheres = association_scope.scope.where_values.map(&:right)
        assert_equal wheres.uniq, wheres
      end
    end
  end
end
