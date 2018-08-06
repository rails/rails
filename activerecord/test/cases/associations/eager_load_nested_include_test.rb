# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/tag"
require "models/author"
require "models/comment"
require "models/category"
require "models/categorization"
require "models/tagging"

class EagerLoadPolyAssocsTest < ActiveRecord::TestCase
  module Remembered
    extend ActiveSupport::Concern

    included do
      after_create :remember
      private
        def remember; self.class.remembered << self; end
    end

    class_methods do
      def remembered; @remembered ||= []; end
      def forget_all; @remembered = nil; end
      def sample; @remembered.sample; end
    end
  end

  class ShapeExpression < ActiveRecord::Base
    belongs_to :shape, polymorphic: true
    belongs_to :paint, polymorphic: true
    include Remembered
  end

  class Circle < ActiveRecord::Base
    has_many :shape_expressions, as: :shape
    include Remembered
  end

  class Square < ActiveRecord::Base
    has_many :shape_expressions, as: :shape
    include Remembered
  end

  class Triangle < ActiveRecord::Base
    has_many :shape_expressions, as: :shape
    include Remembered
  end

  class PaintColor < ActiveRecord::Base
    has_many   :shape_expressions, as: :paint
    belongs_to :non_poly, foreign_key: "non_poly_one_id", class_name: "NonPolyOne"
    include Remembered
  end

  class PaintTexture < ActiveRecord::Base
    has_many   :shape_expressions, as: :paint
    belongs_to :non_poly, foreign_key: "non_poly_two_id", class_name: "NonPolyTwo"
    include Remembered
  end

  class NonPolyOne < ActiveRecord::Base
    has_many :paint_colors
    include Remembered
  end

  class NonPolyTwo < ActiveRecord::Base
    has_many :paint_textures
    include Remembered
  end

  NUM_SIMPLE_OBJS = 3
  NUM_SHAPE_EXPRESSIONS = 6

  def setup
    generate_test_object_graphs
  end

  teardown do
    [Circle, Square, Triangle, PaintColor, PaintTexture,
     ShapeExpression, NonPolyOne, NonPolyTwo]
      .each(&:delete_all)
      .each(&:forget_all)
  end

  def generate_test_object_graphs
    1.upto(NUM_SIMPLE_OBJS) do
      [Circle, Square, Triangle, NonPolyOne, NonPolyTwo].each(&:create!)
    end
    1.upto(NUM_SIMPLE_OBJS) do
      PaintColor.create!(non_poly_one_id: NonPolyOne.sample.id)
      PaintTexture.create!(non_poly_two_id: NonPolyTwo.sample.id)
    end
    1.upto(NUM_SHAPE_EXPRESSIONS / 3) do
      ShapeExpression.create!(shape: Circle.sample, paint: PaintColor.sample)
      ShapeExpression.create!(shape: Square.sample, paint: PaintTexture.sample)
      ShapeExpression.create!(shape: Triangle.sample, paint: PaintTexture.sample)
    end
  end

  def test_preload_query
    subject :preload
  end

  def test_includes_query
    subject :includes
  end

  def subject(eager_type)
    res = ShapeExpression.all.merge!(eager_type => [ { shape: :shape_expressions }, { paint: :non_poly } ])

    assert_queries(1) { res.records }
    assert_equal NUM_SHAPE_EXPRESSIONS, res.size

    # 3 tables for shapes; 2 tables for paints; 2 tables for polys
    # 3 queries for shape_expressions because there is no sti
    assert_queries(10) do
      res.each do |se|
        assert_not_empty se.shape.shape_expressions, "collection nested associations are loaded on demand"
        assert_not_nil se.paint.non_poly, "nested associations are loaded on demand"
      end
    end
  end
end

class EagerLoadNestedIncludeWithMissingDataTest < ActiveRecord::TestCase
  def setup
    @davey_mcdave = Author.create(name: "Davey McDave")
    @first_post = @davey_mcdave.posts.create(title: "Davey Speaks", body: "Expressive wordage")
    @first_comment = @first_post.comments.create(body: "Inflamatory doublespeak")
    @first_categorization = @davey_mcdave.categorizations.create(category: Category.first, post: @first_post)
  end

  teardown do
    @davey_mcdave.destroy
    @first_post.destroy
    @first_comment.destroy
    @first_categorization.destroy
  end

  def test_missing_data_in_a_nested_preload_should_not_cause_errors_when_constructing_objects
    assert_nothing_raised do
      # @davey_mcdave doesn't have any author_favorites
      preload = { posts: :comments, categorizations: :category, author_favorites: :favorite_author }
      Author.all.merge!(preload: preload, where: { authors: { name: @davey_mcdave.name } }).to_a
    end
  end

  def test_missing_data_in_a_nested_include_should_not_cause_errors_when_constructing_objects
    assert_nothing_raised do
      # @davey_mcdave doesn't have any author_favorites
      includes = { posts: :comments, categorizations: :category, author_favorites: :favorite_author }
      Author.all.merge!(includes: includes, where: { authors: { name: @davey_mcdave.name } }, order: "categories.name").to_a
    end
  end
end
