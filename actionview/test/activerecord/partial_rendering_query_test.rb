# frozen_string_literal: true

require "active_record_unit"

class PartialRenderingQueryTest < ActiveRecordTestCase
  def setup
    @view = ActionView::Base
      .with_empty_template_cache
      .with_view_paths(ActionController::Base.view_paths, {})
  end

  def test_render_with_relation_collection
    notifications = capture_notifications("sql.active_record") do
      @view.render partial: "topics/topic", collection: Topic.all
    end

    queries = notifications.filter_map { _1.payload[:sql] unless %w[ SCHEMA TRANSACTION ].include?(_1.payload[:name]) }

    assert_equal 1, queries.size
    assert_equal 'SELECT "topics".* FROM "topics"', queries[0]
  end
end
