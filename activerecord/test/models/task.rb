class Task < ActiveRecord::Base
  belongs_to :parent

  def updated_at
    ending
  end
end

class MainTask < Task
  has_many :sub_tasks, foreign_key: "parent_id"
  has_many :elementary_tasks, through: :sub_tasks, foreign_key: "parent_id"
end

class SubTask < Task
  belongs_to :main_task, foreign_key: "parent_id"
  has_many :elementary_tasks, foreign_key: "parent_id"
end

class ElementaryTask < Task
  belongs_to :sub_task, foreign_key: "parent_id"
end