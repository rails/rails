require 'cases/helper'

class EagerLoadPolyAssocsTest < Test::Unit::TestCase
  NUM_SIMPLE_OBJS = 50
  NUM_SHAPE_EXPRESSIONS = 100

  def setup
    silence_stream(STDOUT) { create_test_tables }
    generate_test_object_graphs
  end

  def create_test_tables
    conn = ActiveRecord::Base.connection

    [:circles, :squares, :triangles, :non_poly_ones, :non_poly_twos].each do |t|
      conn.create_table(t, :force => true) { }
    end

    conn.create_table :shape_expressions, :force => true do |t|
      t.string  :paint_type
      t.integer :paint_id
      t.string  :shape_type
      t.integer :shape_id
    end
    conn.create_table :paint_colors, :force => true do |t|
      t.integer :non_poly_one_id
    end
    conn.create_table :paint_textures, :force => true do |t|
      t.integer :non_poly_two_id
    end
  end

  def teardown
    drop_tables
  end

  def drop_tables
    conn = ActiveRecord::Base.connection
    conn.reconnect!

    silence_stream(STDOUT) do
      [:circles, :squares, :triangles, :paint_colors, :paint_textures,
       :shape_expressions, :non_poly_ones, :non_poly_twos].each do |t|
        conn.drop_table t
      end
    end
  end

  # meant to be supplied as an ID, never returns 0
  def rand_simple
    val = (NUM_SIMPLE_OBJS * rand).round
    val == 0 ? 1 : val
  end

  def generate_test_object_graphs
    1.upto(NUM_SIMPLE_OBJS) do
      [Circle, Square, Triangle, NonPolyOne, NonPolyTwo].map(&:create!)
    end
    1.upto(NUM_SIMPLE_OBJS) do |i|
      PaintColor.create!(:non_poly_one_id => rand_simple)
      PaintTexture.create!(:non_poly_two_id => rand_simple)
    end
    1.upto(NUM_SHAPE_EXPRESSIONS) do |i|
      ShapeExpression.create!(:shape_type => [Circle, Square, Triangle].rand.to_s, :shape_id => rand_simple,
                              :paint_type => [PaintColor, PaintTexture].rand.to_s, :paint_id => rand_simple)
    end
  end

  def test_include_query
    res = 0
    res = ShapeExpression.find :all, :include => [ :shape, { :paint => :non_poly } ]
    assert_equal NUM_SHAPE_EXPRESSIONS, res.size
    ShapeExpression.connection.disconnect!
    assert_nothing_raised "confirm we can access associations in memory" do
      res.each do |se|
        assert_not_nil se.paint.non_poly, "this is the association that was loading incorrectly before the change"
        assert_not_nil se.shape, "just making sure other associations still work"
      end
    end
    assert_raise ActiveRecord::StatementInvalid, "An exception should be raised when db connectivity is required" do
      res[0].reload
    end
  end
end

class ShapeExpression < ActiveRecord::Base
  belongs_to :shape, :polymorphic => true
  belongs_to :paint, :polymorphic => true
end

class Circle < ActiveRecord::Base
  has_many :shape_expressions, :as => :shape
end
class Square < ActiveRecord::Base
  has_many :shape_expressions, :as => :shape
end
class Triangle < ActiveRecord::Base
  has_many :shape_expressions, :as => :shape
end
class PaintColor  < ActiveRecord::Base
  has_many   :shape_expressions, :as => :paint
  belongs_to :non_poly, :foreign_key => "non_poly_one_id", :class_name => "NonPolyOne"
end
class PaintTexture < ActiveRecord::Base
  has_many   :shape_expressions, :as => :paint
  belongs_to :non_poly, :foreign_key => "non_poly_two_id", :class_name => "NonPolyTwo"
end
class NonPolyOne < ActiveRecord::Base
  has_many :paint_colors
end
class NonPolyTwo < ActiveRecord::Base
  has_many :paint_textures
end
