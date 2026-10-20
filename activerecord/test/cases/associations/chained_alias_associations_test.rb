# frozen_string_literal: true

require "cases/helper"
require "models/post"

# Resolving an alias whose target is also an alias twice reaches a different
# column, so these association paths must resolve their keys exactly once.
class ChainedAliasAssociationsTest < ActiveRecord::TestCase
  class PlainComment < ActiveRecord::Base
    self.table_name = "comments"
    self.inheritance_column = nil
  end

  class ChainPost < ActiveRecord::Base
    self.table_name = "posts"
    self.inheritance_column = nil

    has_many :chain_comments,
      class_name: "ChainedAliasAssociationsTest::ChainComment",
      foreign_key: :route_fk,
      inverse_of: :routed_post
  end

  class ChainComment < ActiveRecord::Base
    self.table_name = "comments"
    self.inheritance_column = nil

    alias_attribute :route_fk, :post_id
    alias_attribute :post_id, :author_id

    belongs_to :routed_post,
      class_name: "ChainedAliasAssociationsTest::ChainPost",
      foreign_key: :route_fk,
      inverse_of: :chain_comments,
      optional: true
  end

  class LateAliasComment < ActiveRecord::Base
    self.table_name = "comments"
    self.inheritance_column = nil

    belongs_to :routed_post,
      class_name: "ChainedAliasAssociationsTest::ChainPost",
      foreign_key: :route_fk,
      optional: true

    alias_attribute :route_fk, :post_id
  end

  setup do
    @target = ChainPost.create!(title: "Target", body: "Target")
    @unrelated = ChainPost.create!(title: "Unrelated", body: "Unrelated")
    @row = PlainComment.create!(post_id: @target.id, author_id: @unrelated.id, body: "Chained")
  end

  def test_belongs_to_reads_the_aliased_column
    reference = ChainComment.find(@row.id)
    association = reference.association(:routed_post)

    assert_equal @target, reference.routed_post
    assert_equal @target.id, association.send(:stale_state)
    assert_not association.stale_target?
    assert_equal [reference], ChainComment.where(routed_post: @target).to_a
    assert_equal @target, ChainComment.preload(:routed_post).find(@row.id).routed_post
    assert_equal @target, ChainComment.eager_load(:routed_post).find(@row.id).routed_post
  end

  def test_belongs_to_writes_the_aliased_column
    reference = ChainComment.find(@row.id)
    replacement = ChainPost.create!(title: "Replacement", body: "Replacement")

    reference.routed_post = replacement

    assert_not reference.association(:routed_post).stale_target?
    assert_equal replacement.id, reference._read_attribute("post_id")
    assert_equal @unrelated.id, reference._read_attribute("author_id")
  end

  def test_has_many_writes_the_aliased_column_and_sets_the_inverse
    comment = @target.chain_comments.build(body: "Built")

    assert_equal @target.id, comment._read_attribute("post_id")
    assert_same @target, comment.routed_post
    assert_not comment.association(:routed_post).stale_target?
  end

  def test_alias_declared_after_belongs_to
    reference = LateAliasComment.find(@row.id)
    assert_equal @target, reference.routed_post

    replacement = ChainPost.create!(title: "Replacement", body: "Replacement")
    reference.update!(routed_post: replacement)
    assert_equal replacement.id, PlainComment.find(@row.id).post_id
  end

  def test_has_one_nullifies_the_aliased_column
    owner_class = Class.new(ChainPost) do
      def self.name = "ChainedAliasHasOneOwner"
      has_one :chain_comment, class_name: "ChainedAliasAssociationsTest::ChainComment", foreign_key: :route_fk, dependent: :nullify
    end
    owner = owner_class.find(@target.id)
    comment = ChainComment.find(@row.id)

    owner.association(:chain_comment).send(:nullify_owner_attributes, comment)

    assert_nil comment._read_attribute("post_id")
    assert_equal @unrelated.id, comment._read_attribute("author_id")
  end
end
