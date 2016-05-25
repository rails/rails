require 'cases/helper'
require 'models/post'
require 'models/author'

module ActiveRecord
  module Associations
    class AssociationScopeTest < ActiveRecord::TestCase
      test 'does not duplicate conditions' do
        scope = AssociationScope.scope(Author.new.association(:welcome_posts),
                                        Author.connection)
        binds = scope.where_clause.binds.map(&:value)
        assert_equal binds.uniq, binds
      end

      test 'raises if improperly formatted scope is given' do
        class SpecialPirate < ActiveRecord::Base
          self.table_name = 'pirates'
          has_many :birds, foreign_key: 'pirate_id', class_name: 'SpecialBird'
        end

        class SpecialBird < ActiveRecord::Base
          self.table_name = 'birds'
          belongs_to :pirate, -> { nil }, class_name: 'SpecialPirate'
        end

        pirate = SpecialPirate.create!
        pirate.birds << SpecialBird.create!

        assert_raises ArgumentError, 'nil is not valid scope argument' do
          assert_equal pirate.id, SpecialBird.first.pirate.id
        end
      end
    end
  end
end
