# frozen_string_literal: true

require "cases/helper"

class UnusedDestroyAsync < ActiveRecord::Base
  self.destroy_association_async_job = nil
end

class UnusedBelongsTo < ActiveRecord::Base
  self.destroy_association_async_job = nil
end

class ActiveJobNotPresentTest < ActiveRecord::TestCase
  test "has_one dependent destroy_async requires activejob" do
    assert_raises ActiveRecord::ActiveJobRequiredError do
      UnusedDestroyAsync.has_one :unused_belongs_to, dependent: :destroy_async
    end
  end

  test "has_many dependent destroy_async requires activejob" do
    assert_raises ActiveRecord::ActiveJobRequiredError do
      UnusedDestroyAsync.has_many :essay_destroy_asyncs, dependent: :destroy_async
    end
  end

  test "belong_to dependent destroy_async requires activejob" do
    assert_raises ActiveRecord::ActiveJobRequiredError do
      UnusedBelongsTo.belongs_to :unused_destroy_asyncs, dependent: :destroy_async
    end
  end
end
