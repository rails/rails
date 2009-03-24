require 'cases/helper'
require 'models/author'
require 'models/post'
require 'models/comment'
require 'models/category'
require 'models/categorization'

module Remembered
  def self.included(base)
    base.extend ClassMethods
    base.class_eval do
      after_create :remember
    protected
      def remember; self.class.remembered << self; end
    end
  end

  module ClassMethods
    def remembered; @@remembered ||= []; end
    def rand; @@remembered.rand; end
  end
end

class ShapeExpression < ActiveRecord::Base
  belongs_to :shape, :polymorphic => true
  belongs_to :paint, :polymorphic => true
end

class Circle < ActiveRecord::Base
  has_many :shape_expressions, :as => :shape
  include Remembered
end
class Square < ActiveRecord::Base
  has_many :shape_expressions, :as => :shape
  include Remembered
end
class Triangle < ActiveRecord::Base
  has_many :shape_expressions, :as => :shape
  include Remembered
end
class PaintColor  < ActiveRecord::Base
  has_many   :shape_expressions, :as => :paint
  belongs_to :non_poly, :foreign_key => "non_poly_one_id", :class_name => "NonPolyOne"
  include Remembered
end
class PaintTexture < ActiveRecord::Base
  has_many   :shape_expressions, :as => :paint
  belongs_to :non_poly, :foreign_key => "non_poly_two_id", :class_name => "NonPolyTwo"
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



class EagerLoadPolyAssocsTest < ActiveRecord::TestCase
  NUM_SIMPLE_OBJS = 50
  NUM_SHAPE_EXPRESSIONS = 100

  def setup
    generate_test_object_graphs
  end
  
  def teardown
    [Circle, Square, Triangle, PaintColor, PaintTexture, 
     ShapeExpression, NonPolyOne, NonPolyTwo].each do |c|
      c.delete_all
    end
    
  end


  def generate_test_object_graphs
    1.upto(NUM_SIMPLE_OBJS) do
      [Circle, Square, Triangle, NonPolyOne, NonPolyTwo].map(&:create!)
    end
    1.upto(NUM_SIMPLE_OBJS) do
      PaintColor.create!(:non_poly_one_id => NonPolyOne.rand.id)
      PaintTexture.create!(:non_poly_two_id => NonPolyTwo.rand.id)
    end
    1.upto(NUM_SHAPE_EXPRESSIONS) do
      shape_type = [Circle, Square, Triangle].rand
      paint_type = [PaintColor, PaintTexture].rand
      ShapeExpression.create!(:shape_type => shape_type.to_s, :shape_id => shape_type.rand.id,
                              :paint_type => paint_type.to_s, :paint_id => paint_type.rand.id)
    end
  end

  def test_include_query
    res = 0
    res = ShapeExpression.find :all, :include => [ :shape, { :paint => :non_poly } ]
    assert_equal NUM_SHAPE_EXPRESSIONS, res.size
    assert_queries(0) do
      res.each do |se|
        assert_not_nil se.paint.non_poly, "this is the association that was loading incorrectly before the change"
        assert_not_nil se.shape, "just making sure other associations still work"
      end
    end
  end
end

class EagerLoadNestedIncludeWithMissingDataTest < ActiveRecord::TestCase
  def setup
    @davey_mcdave = Author.create(:name => 'Davey McDave')
    @first_post = @davey_mcdave.posts.create(:title => 'Davey Speaks', :body => 'Expressive wordage')
    @first_comment = @first_post.comments.create(:body => 'Inflamatory doublespeak')
    @first_categorization = @davey_mcdave.categorizations.create(:category => Category.first, :post => @first_post)
  end

  def teardown
    @davey_mcdave.destroy
    @first_post.destroy
    @first_comment.destroy
    @first_categorization.destroy
  end

  def test_missing_data_in_a_nested_include_should_not_cause_errors_when_constructing_objects
    assert_nothing_raised do
      # @davey_mcdave doesn't have any author_favorites
      includes = {:posts => :comments, :categorizations => :category, :author_favorites => :favorite_author }
      Author.all :include => includes, :conditions => {:authors => {:name => @davey_mcdave.name}}, :order => 'categories.name'
    end
  end
end