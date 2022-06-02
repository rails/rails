# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/tagging"

module Namespaced
  class Post < ActiveRecord::Base
    self.table_name = "posts"
    has_one :tagging, as: :taggable, class_name: "Tagging"
  end
end

module FullStiClassNamesSharedTest
  def setup
    @old_store_full_sti_class = ActiveRecord::Base.store_full_sti_class
    ActiveRecord::Base.store_full_sti_class = store_full_sti_class

    post = Namespaced::Post.create(title: "Great stuff", body: "This is not", author_id: 1)
    @tagging = post.create_tagging!
  end

  def teardown
    ActiveRecord::Base.store_full_sti_class = @old_store_full_sti_class
  end

  def test_class_names
    ActiveRecord::Base.store_full_sti_class = !store_full_sti_class
    post = Namespaced::Post.find_by_title("Great stuff")
    assert_equal @tagging, post.tagging

    ActiveRecord::Base.store_full_sti_class = store_full_sti_class
    post = Namespaced::Post.find_by_title("Great stuff")
    assert_equal @tagging, post.tagging
  end

  def test_class_names_with_includes
    ActiveRecord::Base.store_full_sti_class = !store_full_sti_class
    post = Namespaced::Post.includes(:tagging).find_by_title("Great stuff")
    assert_equal @tagging, post.tagging

    ActiveRecord::Base.store_full_sti_class = store_full_sti_class
    post = Namespaced::Post.includes(:tagging).find_by_title("Great stuff")
    assert_equal @tagging, post.tagging
  end

  def test_class_names_with_eager_load
    ActiveRecord::Base.store_full_sti_class = !store_full_sti_class
    post = Namespaced::Post.eager_load(:tagging).find_by_title("Great stuff")
    assert_equal @tagging, post.tagging

    ActiveRecord::Base.store_full_sti_class = store_full_sti_class
    post = Namespaced::Post.eager_load(:tagging).find_by_title("Great stuff")
    assert_equal @tagging, post.tagging
  end

  def test_class_names_with_find_by
    post = Namespaced::Post.find_by_title("Great stuff")

    ActiveRecord::Base.store_full_sti_class = !store_full_sti_class
    assert_equal @tagging, Tagging.find_by(taggable: post)

    ActiveRecord::Base.store_full_sti_class = store_full_sti_class
    assert_equal @tagging, Tagging.find_by(taggable: post)
  end
end

class FullStiClassNamesTest < ActiveRecord::TestCase
  include FullStiClassNamesSharedTest

  private
    def store_full_sti_class
      true
    end
end

class NonFullStiClassNamesTest < ActiveRecord::TestCase
  include FullStiClassNamesSharedTest

  private
    def store_full_sti_class
      false
    end
end

module PolymorphicFullClassNamesSharedTest
  def setup
    @old_store_full_class_name = ActiveRecord::Base.store_full_class_name
    ActiveRecord::Base.store_full_class_name = store_full_class_name

    post = Namespaced::Post.create(title: "Great stuff", body: "This is not", author_id: 1)
    @tagging = post.create_tagging!
  end

  def teardown
    ActiveRecord::Base.store_full_class_name = @old_store_full_class_name
  end

  def test_class_names
    ActiveRecord::Base.store_full_class_name = !store_full_class_name
    post = Namespaced::Post.find_by_title("Great stuff")
    assert_nil post.tagging

    ActiveRecord::Base.store_full_class_name = store_full_class_name
    post = Namespaced::Post.find_by_title("Great stuff")
    assert_equal @tagging, post.tagging
  end

  def test_class_names_with_includes
    ActiveRecord::Base.store_full_class_name = !store_full_class_name
    post = Namespaced::Post.includes(:tagging).find_by_title("Great stuff")
    assert_nil post.tagging

    ActiveRecord::Base.store_full_class_name = store_full_class_name
    post = Namespaced::Post.includes(:tagging).find_by_title("Great stuff")
    assert_equal @tagging, post.tagging
  end

  def test_class_names_with_eager_load
    ActiveRecord::Base.store_full_class_name = !store_full_class_name
    post = Namespaced::Post.eager_load(:tagging).find_by_title("Great stuff")
    assert_nil post.tagging

    ActiveRecord::Base.store_full_class_name = store_full_class_name
    post = Namespaced::Post.eager_load(:tagging).find_by_title("Great stuff")
    assert_equal @tagging, post.tagging
  end

  def test_class_names_with_find_by
    post = Namespaced::Post.find_by_title("Great stuff")

    ActiveRecord::Base.store_full_class_name = !store_full_class_name
    assert_nil Tagging.find_by(taggable: post)

    ActiveRecord::Base.store_full_class_name = store_full_class_name
    assert_equal @tagging, Tagging.find_by(taggable: post)
  end
end

class PolymorphicFullClassNamesTest < ActiveRecord::TestCase
  include PolymorphicFullClassNamesSharedTest

  private
    def store_full_class_name
      true
    end
end

class PolymorphicNonFullClassNamesTest < ActiveRecord::TestCase
  include PolymorphicFullClassNamesSharedTest

  private
    def store_full_class_name
      false
    end
end
