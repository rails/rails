# frozen_string_literal: true

require "active_record_unit"

class PartialRenderingQueryTest < ActiveRecordTestCase
  def setup
    @view = ActionView::Base
      .with_empty_template_cache
      .with_view_paths(ActionController::Base.view_paths, {})

    @queries = []

    ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      @queries << payload[:sql] unless %w[ SCHEMA TRANSACTION ].include?(payload[:name])
    end
  end

  def test_render_with_relation_collection
    @view.render partial: "topics/topic", collection: Topic.all

    assert_equal 1, @queries.size
    assert_equal 'SELECT "topics".* FROM "topics"', @queries[0]
  end
end
