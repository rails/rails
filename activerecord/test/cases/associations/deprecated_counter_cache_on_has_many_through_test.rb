require "cases/helper"

class DeprecatedCounterCacheOnHasManyThroughTest < ActiveRecord::TestCase
  class Post < ActiveRecord::Base
    has_many :taggings, as: :taggable
    has_many :tags, through: :taggings
  end

  class Tagging < ActiveRecord::Base
    belongs_to :taggable, polymorphic: true
    belongs_to :tag
  end

  class Tag < ActiveRecord::Base
  end

  test "counter caches are updated in the database if the belongs_to association doesn't specify a counter cache" do
    post = Post.create!(title: 'Hello', body: 'World!')
    assert_deprecated { post.tags << Tag.create!(name: 'whatever') }

    assert_equal 1, post.tags.size
    assert_equal 1, post.tags_count
    assert_equal 1, post.reload.tags.size
    assert_equal 1, post.reload.tags_count
  end
end
