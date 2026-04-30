# frozen_string_literal: true

require "cases/helper"

# Regression for https://github.com/rails/rails/issues/52061
class IncludesScopedThroughBatchTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    super
    @connection = ActiveRecord::Base.lease_connection
    @token = SecureRandom.hex(4)
    @const_name = :"Issue52061#{@token}"
    @mod = Object.const_set(@const_name, Module.new)
    m = @mod

    works_t = "works_#{@token}"
    tags_t = "tags_#{@token}"
    taggings_t = "taggings_#{@token}"

    @connection.create_table works_t, force: true
    @connection.create_table tags_t, force: true do |t|
      t.string :type
      t.integer :merger_id
    end
    @connection.create_table taggings_t, force: true do |t|
      t.integer :tag_id
      t.string :tag_type, limit: 100, default: ""
      t.integer :work_id
    end

    m.const_set(:Tagging, Class.new(ActiveRecord::Base) do
      self.table_name = taggings_t
    end)

    m.const_set(:Tag, Class.new(ActiveRecord::Base) do
      self.table_name = tags_t
      self.inheritance_column = "type"
    end)

    m.const_set(:Work, Class.new(ActiveRecord::Base) do
      self.table_name = works_t
    end)

    m.const_set(:Fandom, Class.new(m::Tag))
    m.const_set(:Relationship, Class.new(m::Tag))

    m::Tag.const_set(:TYPES, ["Fandom", "Relationship"].freeze)

    m::Tag.class_eval do
      has_many :mergers, foreign_key: "merger_id", class_name: name
      belongs_to :merger, class_name: name, optional: true

      has_many :taggings, class_name: m::Tagging.name, inverse_of: :tag
    end

    m::Tagging.class_eval do
      belongs_to :tag, polymorphic: true, inverse_of: :taggings
      belongs_to :work, class_name: m::Work.name, inverse_of: :taggings
    end

    m::Work.class_eval do
      has_many :taggings, class_name: m::Tagging.name, inverse_of: :work
      has_many :tags, through: :taggings, source: :tag

      # Qualified on Tag#arel_table: `where(tags: { ... })` would reference the
      # logical name "tags", not Tag.table_name ("tags_<token>" in this test).
      tags_table = m::Tag.arel_table
      m::Tag::TYPES.each do |type_name|
        type_model = m.const_get(type_name)
        has_many type_name.underscore.pluralize.to_sym,
          # STI discriminator matches #sti_name (full class name under default Rails settings).
          -> { where(tags_table[:type].eq(type_model.sti_name)) },
          through: :taggings,
          source: :tag,
          source_type: m::Tag.name # not "Tag": constantize resolves under this test module
      end
    end
  end

  def teardown
    @connection.drop_table "taggings_#{@token}", if_exists: true
    @connection.drop_table "tags_#{@token}", if_exists: true
    @connection.drop_table "works_#{@token}", if_exists: true
    Object.send(:remove_const, @const_name)
    super
  end

  def test_parallel_scoped_through_includes_nested_self_association
    m = @mod
    f1 = m::Fandom.create!
    rel1 = m::Relationship.create!
    work = m::Work.create!
    # Persist first; multiple scoped throughs on shared join must add rows sequentially
    # (assigning both in one create! can leave only one side’s taggings depending on reflection merge).
    work.fandoms << f1
    work.relationships << rel1

    bare = m::Work.first
    assert_equal 1, bare.fandoms.count
    assert_equal 1, bare.relationships.count
    assert_instance_of m::Fandom, bare.fandoms.sole
    assert_instance_of m::Relationship, bare.relationships.sole

    loaded = m::Work.includes(fandoms: :merger, relationships: :merger).first
    assert_equal 1, loaded.fandoms.count
    assert_equal 1, loaded.relationships.count
    assert_instance_of m::Fandom, loaded.fandoms.sole
    assert_instance_of m::Relationship, loaded.relationships.sole
  end
end
