require 'cases/helper'
require 'models/post'
require 'models/author'

module ActiveRecord
  module Associations
    class AssociationScopeTest < ActiveRecord::TestCase
      test 'does not duplicate conditions' do
        association_scope = AssociationScope.new(Author.new.association(:welcome_posts))
        scope = association_scope.scope
        binds = scope.bind_values.map(&:last)
        wheres = scope.where_values.map(&:right).reject { |node|
          Arel::Nodes::BindParam === node
        }
        assert_equal wheres.uniq, wheres
        assert_equal binds.uniq, binds
      end
    end
  end
end
