# frozen_string_literal: true

require "cases/helper"
require "active_record/associations/counter_cache_registry"

module CounterCacheLoadOrderTestClasses; end

class CounterCacheLoadOrderTest < ActiveRecord::TestCase
  def setup
    ActiveRecord::Associations::CounterCacheRegistry.clear
  end

  def teardown
    CounterCacheLoadOrderTestClasses.send(:remove_const, :TestComment) if defined?(CounterCacheLoadOrderTestClasses::TestComment)
    CounterCacheLoadOrderTestClasses.send(:remove_const, :TestPost) if defined?(CounterCacheLoadOrderTestClasses::TestPost)
  end

  test "counter cache works when associated class is loaded after the model with belongs_to" do
    class CounterCacheLoadOrderTestClasses::TestComment < ActiveRecord::Base
      self.table_name = "comments"
      belongs_to :post, counter_cache: true, class_name: "CounterCacheLoadOrderTestClasses::TestPost"
    end

    class CounterCacheLoadOrderTestClasses::TestPost < ActiveRecord::Base
      self.table_name = "posts"
    end

    assert CounterCacheLoadOrderTestClasses::TestPost.counter_cache_column?("test_comments_count")
  end

  test "counter cache works with custom counter cache column name" do
    class CounterCacheLoadOrderTestClasses::TestComment < ActiveRecord::Base
      self.table_name = "comments"
      belongs_to :post, counter_cache: :custom_comments_count, class_name: "CounterCacheLoadOrderTestClasses::TestPost"
    end

    class CounterCacheLoadOrderTestClasses::TestPost < ActiveRecord::Base
      self.table_name = "posts"
    end

    assert CounterCacheLoadOrderTestClasses::TestPost.counter_cache_column?("custom_comments_count")
  end
end
