# frozen_string_literal: true

class MyPost < ActiveRecord::Base
  self.table_name = "my_posts"
  has_many :comments
  def self.test_restart_parent_transaction
    post = self.first
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.transaction(requires_new: true) do
        post.destroy
        raise "Rollback"
      end
    end
  rescue
    post.destroy
  end
  def self.test_savepoint_transaction
    post = nil
    ActiveRecord::Base.transaction do
        post = self.first
        ActiveRecord::Base.transaction(requires_new: true) do
          post.destroy
          raise "Rollback"
        end
      end
  rescue
    post.destroy
  end
end
