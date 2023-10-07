# frozen_string_literal: true

# test that attr_readonly isn't called on the :taggable polymorphic association
module Taggable
end

class Tagging < ActiveRecord::Base
  belongs_to :tag, -> { includes(:tagging) }, optional: true
  belongs_to :super_tag,   class_name: "Tag", foreign_key: "super_tag_id", optional: true
  belongs_to :invalid_tag, class_name: "Tag", foreign_key: "tag_id", optional: true
  belongs_to :ordered_tag, class_name: "OrderedTag", foreign_key: "tag_id", optional: true
  belongs_to :blue_tag, -> { where tags: { name: "Blue" } }, class_name: "Tag", foreign_key: :tag_id, optional: true
  belongs_to :tag_with_primary_key, class_name: "Tag", foreign_key: :tag_id, primary_key: :custom_primary_key, optional: true
  belongs_to :taggable, polymorphic: true, counter_cache: :tags_count, optional: true
  has_many :things, through: :taggable
end

class IndestructibleTagging < Tagging
  before_destroy { throw :abort }
end
