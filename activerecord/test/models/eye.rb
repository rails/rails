# frozen_string_literal: true

class Eye < ActiveRecord::Base
  attr_reader :after_create_callbacks_stack
  attr_reader :after_update_callbacks_stack
  attr_reader :after_save_callbacks_stack
  attr_writer :override_iris_with_read_only_foreign_key_color

  # Callbacks configured before the ones has_one sets up.
  after_create :trace_after_create, if: :iris
  after_update :trace_after_update, if: :iris
  after_save   :trace_after_save, if: :iris

  has_one :iris
  accepts_nested_attributes_for :iris

  # Callbacks configured after the ones has_one sets up.
  after_create :trace_after_create2, if: :iris
  after_update :trace_after_update2, if: :iris
  after_save   :trace_after_save2, if: :iris

  def trace_after_create
    (@after_create_callbacks_stack ||= []) << !iris.persisted?
  end
  alias trace_after_create2 trace_after_create

  def trace_after_update
    (@after_update_callbacks_stack ||= []) << iris.has_changes_to_save?
  end
  alias trace_after_update2 trace_after_update

  def trace_after_save
    (@after_save_callbacks_stack ||= []) << iris.has_changes_to_save?
  end
  alias trace_after_save2 trace_after_save

  has_one :iris_with_read_only_foreign_key, class_name: "IrisWithReadOnlyForeignKey", foreign_key: :eye_id
  accepts_nested_attributes_for :iris_with_read_only_foreign_key

  before_save :set_iris_with_read_only_foreign_key_color_to_blue, if: -> {
    iris_with_read_only_foreign_key && @override_iris_with_read_only_foreign_key_color
  }

  def set_iris_with_read_only_foreign_key_color_to_blue
    iris_with_read_only_foreign_key.color = "blue"
  end
end

class Iris < ActiveRecord::Base
  belongs_to :eye
end

class IrisWithReadOnlyForeignKey < Iris
  attr_readonly :eye_id
end
