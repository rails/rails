require "cases/helper"
require 'models/topic'
require 'models/author'
require 'models/book'

module ActiveRecord
  class PredicateBuilderTest < ActiveRecord::TestCase
    def test_registering_new_handlers
      PredicateBuilder.register_handler(Regexp, proc do |column, value|
        Arel::Nodes::InfixOperation.new('~', column, Arel.sql(value.source))
      end)

      assert_match %r{["`]topics["`].["`]title["`] ~ rails}i, Topic.where(title: /rails/).to_sql
    end

    def test_selectmanager_handler
      author = Author.create!(name: 'Steven King')
      Book.create!(author_id: author.id)
      Book.create!(author_id: author.id)

      assert_equal author, Author.where(id: Book.arel_table.project(:author_id)).first
    end
  end
end
