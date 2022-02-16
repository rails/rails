# frozen_string_literal: true

class EssayDestroyAsync < ActiveRecord::Base
  self.table_name = "essays"
  belongs_to :book, dependent: :destroy_async, class_name: "BookDestroyAsync"
end

class LongEssayDestroyAsync < EssayDestroyAsync
end

class ShortEssayDestroyAsync < EssayDestroyAsync
end

class EssayWithDestroyingAsyncCallback < ActiveRecord::Base
  self.table_name = "essays"
  around_destroy :callback, if: :destroying_async?

  private
    def callback
      before_destroying_async
      yield
    end

    def before_destroying_async; end
end
