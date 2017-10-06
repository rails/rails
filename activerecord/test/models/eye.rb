# frozen_string_literal: true

class Eye < ActiveRecord::Base
  attr_reader :after_create_callbacks_stack
  attr_reader :after_update_callbacks_stack
  attr_reader :after_save_callbacks_stack

  # Callbacks configured before the ones has_one sets up.
  after_create :trace_after_create
  after_update :trace_after_update
  after_save   :trace_after_save

  has_one :iris
  accepts_nested_attributes_for :iris

  # Callbacks configured after the ones has_one sets up.
  after_create :trace_after_create2
  after_update :trace_after_update2
  after_save   :trace_after_save2

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
end

class Iris < ActiveRecord::Base
  belongs_to :eye
end
