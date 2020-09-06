# frozen_string_literal: true

require 'cases/helper'
require 'models/reply'

module ActiveRecord
  class PredicateBuilderTest < ActiveRecord::TestCase
    def setup
      Topic.predicate_builder.register_handler(Regexp, proc do |column, value|
        Arel::Nodes::InfixOperation.new('~', column, Arel::Nodes.build_quoted(value.source))
      end)
    end

    def teardown
      Topic.class_eval { @predicate_builder = nil }
    end

    def test_registering_new_handlers
      assert_match %r{#{Regexp.escape(topic_title)} ~ 'rails'}i, Topic.where(title: /rails/).to_sql
    end

    def test_registering_new_handlers_for_association
      assert_match %r{#{Regexp.escape(topic_title)} ~ 'rails'}i, Reply.joins(:topic).where(topics: { title: /rails/ }).to_sql
    end

    private
      def topic_title
        Topic.connection.quote_table_name('topics.title')
      end
  end
end
