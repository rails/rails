# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/computer"

class CallbackDeveloper < ActiveRecord::Base
  self.table_name = "developers"

  class << self
    def callback_proc(callback_method)
      Proc.new { |model| model.history << [callback_method, :proc] }
    end

    def define_callback_method(callback_method)
      define_method(callback_method) do
        history << [callback_method, :method]
      end
      send(callback_method, :"#{callback_method}")
    end

    def callback_object(callback_method)
      klass = Class.new
      klass.define_method(callback_method) do |model|
        model.history << [callback_method, :object]
      end
      klass.new
    end
  end

  ActiveRecord::Callbacks::CALLBACKS.each do |callback_method|
    next if callback_method.start_with?("around_")
    define_callback_method(callback_method)
    send(callback_method, callback_proc(callback_method))
    send(callback_method, callback_object(callback_method))
    send(callback_method) { |model| model.history << [callback_method, :block] }
  end

  def history
    @history ||= []
  end
end

class CallbackDeveloperWithHaltedValidation < CallbackDeveloper
  before_validation proc { |model| model.history << [:before_validation, :throwing_abort]; throw(:abort) }
  before_validation proc { |model| model.history << [:before_validation, :should_never_get_here] }
end

class ParentDeveloper < ActiveRecord::Base
  self.table_name = "developers"
  attr_accessor :after_save_called
  before_validation { |record| record.after_save_called = true }
end

class ChildDeveloper < ParentDeveloper
end

class ImmutableDeveloper < ActiveRecord::Base
  self.table_name = "developers"

  validates_inclusion_of :salary, in: 50000..200000

  before_save :cancel
  before_destroy :cancel

  private
    def cancel
      false
    end
end

class DeveloperWithCanceledCallbacks < ActiveRecord::Base
  self.table_name = "developers"

  validates_inclusion_of :salary, in: 50000..200000

  before_save :cancel
  before_destroy :cancel

  private
    def cancel
      throw(:abort)
    end
end

class OnCallbacksDeveloper < ActiveRecord::Base
  self.table_name = "developers"

  before_validation { history << :before_validation }
  before_validation(on: :create) { history << :before_validation_on_create }
  before_validation(on: :update) { history << :before_validation_on_update }

  validate do
    history << :validate
  end

  after_validation { history << :after_validation }
  after_validation(on: :create) { history << :after_validation_on_create }
  after_validation(on: :update) { history << :after_validation_on_update }

  def history
    @history ||= []
  end
end

class ContextualCallbacksDeveloper < ActiveRecord::Base
  self.table_name = "developers"

  before_validation { history << :before_validation }
  before_validation :before_validation_on_create_and_update, on: [ :create, :update ]

  validate do
    history << :validate
  end

  after_validation { history << :after_validation }
  after_validation :after_validation_on_create_and_update, on: [ :create, :update ]

  def before_validation_on_create_and_update
    history << "before_validation_on_#{validation_context}".to_sym
  end

  def after_validation_on_create_and_update
    history << "after_validation_on_#{validation_context}".to_sym
  end

  def history
    @history ||= []
  end
end

class CallbackHaltedDeveloper < ActiveRecord::Base
  self.table_name = "developers"

  attr_reader   :after_save_called, :after_create_called, :after_update_called, :after_destroy_called
  attr_accessor :cancel_before_save, :cancel_before_create, :cancel_before_update, :cancel_before_destroy

  before_save    { throw(:abort) if defined?(@cancel_before_save) }
  before_create  { throw(:abort) if @cancel_before_create  }
  before_update  { throw(:abort) if @cancel_before_update  }
  before_destroy { throw(:abort) if @cancel_before_destroy }

  after_save    { @after_save_called    = true }
  after_update  { @after_update_called  = true }
  after_create  { @after_create_called  = true }
  after_destroy { @after_destroy_called = true }
end

class CallbacksTest < ActiveRecord::TestCase
  fixtures :developers

  def test_initialize
    david = CallbackDeveloper.new
    assert_equal [
      [ :after_initialize,            :method ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
    ], david.history
  end

  def test_find
    david = CallbackDeveloper.find(1)
    assert_equal [
      [ :after_find,            :method ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :method ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
    ], david.history
  end

  def test_new_valid?
    david = CallbackDeveloper.new
    david.valid?
    assert_equal [
      [ :after_initialize,            :method ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
    ], david.history
  end

  def test_existing_valid?
    david = CallbackDeveloper.find(1)
    david.valid?
    assert_equal [
      [ :after_find,            :method ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :method ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
    ], david.history
  end

  def test_create
    david = CallbackDeveloper.create("name" => "David", "salary" => 1000000)
    assert_equal [
      [ :after_initialize,            :method ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :before_save,                 :method ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_create,               :method ],
      [ :before_create,               :proc   ],
      [ :before_create,               :object ],
      [ :before_create,               :block  ],
      [ :after_create,                :method ],
      [ :after_create,                :proc   ],
      [ :after_create,                :object ],
      [ :after_create,                :block  ],
      [ :after_save,                  :method ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ],
      [ :after_commit,                :block  ],
      [ :after_commit,                :object ],
      [ :after_commit,                :proc   ],
      [ :after_commit,                :method ]
    ], david.history
  end

  def test_validate_on_create
    david = OnCallbacksDeveloper.create("name" => "David", "salary" => 1000000)
    assert_equal [
      :before_validation,
      :before_validation_on_create,
      :validate,
      :after_validation,
      :after_validation_on_create
    ], david.history
  end

  def test_validate_on_contextual_create
    david = ContextualCallbacksDeveloper.create("name" => "David", "salary" => 1000000)
    assert_equal [
      :before_validation,
      :before_validation_on_create,
      :validate,
      :after_validation,
      :after_validation_on_create
    ], david.history
  end

  def test_update
    david = CallbackDeveloper.find(1)
    david.save
    assert_equal [
      [ :after_find,            :method ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :method ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :before_save,                 :method ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_update,               :method ],
      [ :before_update,               :proc   ],
      [ :before_update,               :object ],
      [ :before_update,               :block  ],
      [ :after_update,                :method ],
      [ :after_update,                :proc   ],
      [ :after_update,                :object ],
      [ :after_update,                :block  ],
      [ :after_save,                  :method ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ],
      [ :after_commit,                :block  ],
      [ :after_commit,                :object ],
      [ :after_commit,                :proc   ],
      [ :after_commit,                :method ]
    ], david.history
  end

  def test_validate_on_update
    david = OnCallbacksDeveloper.find(1)
    david.save
    assert_equal [
      :before_validation,
      :before_validation_on_update,
      :validate,
      :after_validation,
      :after_validation_on_update
    ], david.history
  end

  def test_validate_on_contextual_update
    david = ContextualCallbacksDeveloper.find(1)
    david.save
    assert_equal [
      :before_validation,
      :before_validation_on_update,
      :validate,
      :after_validation,
      :after_validation_on_update
    ], david.history
  end

  def test_destroy
    david = CallbackDeveloper.find(1)
    david.destroy
    assert_equal [
      [ :after_find,            :method ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :method ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_destroy,              :method ],
      [ :before_destroy,              :proc   ],
      [ :before_destroy,              :object ],
      [ :before_destroy,              :block  ],
      [ :after_destroy,               :method ],
      [ :after_destroy,               :proc   ],
      [ :after_destroy,               :object ],
      [ :after_destroy,               :block  ],
      [ :after_commit,                :block  ],
      [ :after_commit,                :object ],
      [ :after_commit,                :proc   ],
      [ :after_commit,                :method ]
    ], david.history
  end

  def test_delete
    david = CallbackDeveloper.find(1)
    CallbackDeveloper.delete(david.id)
    assert_equal [
      [ :after_find,            :method ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :method ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
    ], david.history
  end

  def assert_save_callbacks_not_called(someone)
    assert_not someone.after_save_called
    assert_not someone.after_create_called
    assert_not someone.after_update_called
  end
  private :assert_save_callbacks_not_called

  def test_before_create_throwing_abort
    someone = CallbackHaltedDeveloper.new
    someone.cancel_before_create = true
    assert_predicate someone, :valid?
    assert_not someone.save
    assert_save_callbacks_not_called(someone)
  end

  def test_before_save_throwing_abort
    david = DeveloperWithCanceledCallbacks.find(1)
    assert_predicate david, :valid?
    assert_not david.save
    exc = assert_raise(ActiveRecord::RecordNotSaved) { david.save! }
    assert_equal david, exc.record

    david = DeveloperWithCanceledCallbacks.find(1)
    david.salary = 10_000_000
    assert_not_predicate david, :valid?
    assert_not david.save
    assert_raise(ActiveRecord::RecordInvalid) { david.save! }

    someone = CallbackHaltedDeveloper.find(1)
    someone.cancel_before_save = true
    assert_predicate someone, :valid?
    assert_not someone.save
    assert_save_callbacks_not_called(someone)
  end

  def test_before_update_throwing_abort
    someone = CallbackHaltedDeveloper.find(1)
    someone.cancel_before_update = true
    assert_predicate someone, :valid?
    assert_not someone.save
    assert_save_callbacks_not_called(someone)
  end

  def test_before_destroy_throwing_abort
    david = DeveloperWithCanceledCallbacks.find(1)
    assert_not david.destroy
    exc = assert_raise(ActiveRecord::RecordNotDestroyed) { david.destroy! }
    assert_equal david, exc.record
    assert_not_nil ImmutableDeveloper.find_by_id(1)

    someone = CallbackHaltedDeveloper.find(1)
    someone.cancel_before_destroy = true
    assert_not someone.destroy
    assert_raise(ActiveRecord::RecordNotDestroyed) { someone.destroy! }
    assert_not someone.after_destroy_called
  end

  def test_callback_throwing_abort
    david = CallbackDeveloperWithHaltedValidation.find(1)
    david.save
    assert_equal [
      [ :after_find,        :method ],
      [ :after_find,        :proc   ],
      [ :after_find,        :object ],
      [ :after_find,        :block  ],
      [ :after_initialize,  :method ],
      [ :after_initialize,  :proc   ],
      [ :after_initialize,  :object ],
      [ :after_initialize,  :block  ],
      [ :before_validation, :method ],
      [ :before_validation, :proc   ],
      [ :before_validation, :object ],
      [ :before_validation, :block  ],
      [ :before_validation, :throwing_abort ],
    ], david.history
  end

  def test_inheritance_of_callbacks
    parent = ParentDeveloper.new
    assert_not parent.after_save_called
    parent.save
    assert parent.after_save_called

    child = ChildDeveloper.new
    assert_not child.after_save_called
    child.save
    assert child.after_save_called
  end

  def test_before_save_doesnt_allow_on_option
    exception = assert_raises ArgumentError do
      Class.new(ActiveRecord::Base) do
        before_save(on: :create) { }
      end
    end
    assert_equal "Unknown key: :on. Valid keys are: :if, :unless, :prepend", exception.message
  end

  def test_around_save_doesnt_allow_on_option
    exception = assert_raises ArgumentError do
      Class.new(ActiveRecord::Base) do
        around_save(on: :create) { }
      end
    end
    assert_equal "Unknown key: :on. Valid keys are: :if, :unless, :prepend", exception.message
  end

  def test_after_save_doesnt_allow_on_option
    exception = assert_raises ArgumentError do
      Class.new(ActiveRecord::Base) do
        after_save(on: :create) { }
      end
    end
    assert_equal "Unknown key: :on. Valid keys are: :if, :unless, :prepend", exception.message
  end
end
