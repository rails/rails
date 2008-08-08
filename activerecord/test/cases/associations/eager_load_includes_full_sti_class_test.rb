require 'cases/helper'
require 'models/post'
require 'models/tagging'

module Namespaced
  class Post < ActiveRecord::Base
    set_table_name 'posts'
    has_one :tagging, :as => :taggable, :class_name => 'Tagging'
  end
end

class EagerLoadIncludeFullStiClassNamesTest < ActiveRecord::TestCase

  def setup
    generate_test_objects
  end

  def generate_test_objects
    post = Namespaced::Post.create( :title => 'Great stuff', :body => 'This is not', :author_id => 1 )
    tagging = Tagging.create( :taggable => post )
  end

  def test_class_names
    old = ActiveRecord::Base.store_full_sti_class

    ActiveRecord::Base.store_full_sti_class = false
    post = Namespaced::Post.find_by_title( 'Great stuff', :include => :tagging )
    assert_nil post.tagging

    ActiveRecord::Base.store_full_sti_class = true
    post = Namespaced::Post.find_by_title( 'Great stuff', :include => :tagging )
    assert_equal 'Tagging', post.tagging.class.name
  ensure
    ActiveRecord::Base.store_full_sti_class = old
  end
end
