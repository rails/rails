require 'helper'

module Arel
  describe 'activerecord compatibility' do
    describe 'select manager' do
      it 'provides wheres' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.where table[:id].eq 1
        manager.where table[:name].eq 'Aaron'

        manager.wheres.map { |x|
          x.value
        }.join(', ').must_equal "\"users\".\"id\" = 1, \"users\".\"name\" = 'Aaron'"
      end
    end
  end
end
