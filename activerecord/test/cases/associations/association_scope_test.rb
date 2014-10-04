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
