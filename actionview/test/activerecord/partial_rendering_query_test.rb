# frozen_string_literal: true

require "active_record_unit"

class PartialRenderingQueryTest < ActiveRecordTestCase
  def setup
    @view = ActionView::Base
      .with_empty_template_cache
      .with_view_paths(ActionController::Base.view_paths, {})
  end

  def test_render_with_relation_collection
    assert_notifications_count("sql.active_record", 1) do
      assert_notification("sql.active_record", sql: 'SELECT "topics".* FROM "topics"') do
        @view.render partial: "topics/topic", collection: Topic.all
      end
    end
  end
end
