# frozen_string_literal: true

require "cases/helper"
require "models/publication"
require "models/editorship"
require "models/editor"

class ReloadAssociationCacheTest < ActiveRecord::TestCase
  def test_reload_sets_correct_owner_for_association_cache
    publication = Publication.create!(name: "Rails Way")
    assert_equal "Rails Way (touched)", publication.name
    publication.reload
    assert_equal "Rails Way", publication.name
    publication.transaction do
      publication.editors = [publication.build_editor_in_chief(name: "Alex Black")]
      publication.save!
    end
    assert_equal "Rails Way (touched)", publication.name
  end
end
