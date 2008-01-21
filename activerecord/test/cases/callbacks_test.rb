require "cases/helper"

class CallbackDeveloper < ActiveRecord::Base
  set_table_name 'developers'

  class << self
    def callback_string(callback_method)
      "history << [#{callback_method.to_sym.inspect}, :string]"
    end

    def callback_proc(callback_method)
      Proc.new { |model| model.history << [callback_method, :proc] }
    end

    def define_callback_method(callback_method)
      define_method("#{callback_method}_method") do |model|
        model.history << [callback_method, :method]
      end
    end

    def callback_object(callback_method)
      klass = Class.new
      klass.send(:define_method, callback_method) do |model|
        model.history << [callback_method, :object]
      end
      klass.new
    end
  end

  ActiveRecord::Callbacks::CALLBACKS.each do |callback_method|
    callback_method_sym = callback_method.to_sym
    define_callback_method(callback_method_sym)
    send(callback_method, callback_method_sym)
    send(callback_method, callback_string(callback_method_sym))
    send(callback_method, callback_proc(callback_method_sym))
    send(callback_method, callback_object(callback_method_sym))
    send(callback_method) { |model| model.history << [callback_method_sym, :block] }
  end

  def history
    @history ||= []
  end

  # after_initialize and after_find are invoked only if instance methods have been defined.
  def after_initialize
  end

  def after_find
  end
end

class ParentDeveloper < ActiveRecord::Base
  set_table_name 'developers'
  attr_accessor :after_save_called
  before_validation {|record| record.after_save_called = true}
end

class ChildDeveloper < ParentDeveloper

end

class RecursiveCallbackDeveloper < ActiveRecord::Base
  set_table_name 'developers'

  before_save :on_before_save
  after_save :on_after_save

  attr_reader :on_before_save_called, :on_after_save_called

  def on_before_save
    @on_before_save_called ||= 0
    @on_before_save_called += 1
    save unless @on_before_save_called > 1
  end

  def on_after_save
    @on_after_save_called ||= 0
    @on_after_save_called += 1
    save unless @on_after_save_called > 1
  end
end

class ImmutableDeveloper < ActiveRecord::Base
  set_table_name 'developers'

  validates_inclusion_of :salary, :in => 50000..200000

  before_save :cancel
  before_destroy :cancel

  def cancelled?
    @cancelled == true
  end

  private
    def cancel
      @cancelled = true
      false
    end
end

class ImmutableMethodDeveloper < ActiveRecord::Base
  set_table_name 'developers'

  validates_inclusion_of :salary, :in => 50000..200000

  def cancelled?
    @cancelled == true
  end

  def before_save
    @cancelled = true
    false
  end

  def before_destroy
    @cancelled = true
    false
  end
end

class CallbackCancellationDeveloper < ActiveRecord::Base
  set_table_name 'developers'
  def before_create
    false
  end
end

class CallbacksTest < ActiveRecord::TestCase
  fixtures :developers

  def test_initialize
    david = CallbackDeveloper.new
    assert_equal [
      [ :after_initialize,            :string ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
    ], david.history
  end

  def test_find
    david = CallbackDeveloper.find(1)
    assert_equal [
      [ :after_find,            :string ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :string ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
    ], david.history
  end

  def test_new_valid?
    david = CallbackDeveloper.new
    david.valid?
    assert_equal [
      [ :after_initialize,            :string ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_validation,           :string ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :before_validation_on_create, :string ],
      [ :before_validation_on_create, :proc   ],
      [ :before_validation_on_create, :object ],
      [ :before_validation_on_create, :block  ],
      [ :after_validation,            :string ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :after_validation_on_create,  :string ],
      [ :after_validation_on_create,  :proc   ],
      [ :after_validation_on_create,  :object ],
      [ :after_validation_on_create,  :block  ]
    ], david.history
  end

  def test_existing_valid?
    david = CallbackDeveloper.find(1)
    david.valid?
    assert_equal [
      [ :after_find,            :string ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :string ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_validation,           :string ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :before_validation_on_update, :string ],
      [ :before_validation_on_update, :proc   ],
      [ :before_validation_on_update, :object ],
      [ :before_validation_on_update, :block  ],
      [ :after_validation,            :string ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :after_validation_on_update,  :string ],
      [ :after_validation_on_update,  :proc   ],
      [ :after_validation_on_update,  :object ],
      [ :after_validation_on_update,  :block  ]
    ], david.history
  end

  def test_create
    david = CallbackDeveloper.create('name' => 'David', 'salary' => 1000000)
    assert_equal [
      [ :after_initialize,            :string ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_validation,           :string ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :before_validation_on_create, :string ],
      [ :before_validation_on_create, :proc   ],
      [ :before_validation_on_create, :object ],
      [ :before_validation_on_create, :block  ],
      [ :after_validation,            :string ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :after_validation_on_create,  :string ],
      [ :after_validation_on_create,  :proc   ],
      [ :after_validation_on_create,  :object ],
      [ :after_validation_on_create,  :block  ],
      [ :before_save,                 :string ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_create,               :string ],
      [ :before_create,               :proc   ],
      [ :before_create,               :object ],
      [ :before_create,               :block  ],
      [ :after_create,                :string ],
      [ :after_create,                :proc   ],
      [ :after_create,                :object ],
      [ :after_create,                :block  ],
      [ :after_save,                  :string ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ]
    ], david.history
  end

  def test_save
    david = CallbackDeveloper.find(1)
    david.save
    assert_equal [
      [ :after_find,            :string ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :string ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_validation,           :string ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :before_validation_on_update, :string ],
      [ :before_validation_on_update, :proc   ],
      [ :before_validation_on_update, :object ],
      [ :before_validation_on_update, :block  ],
      [ :after_validation,            :string ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :after_validation_on_update,  :string ],
      [ :after_validation_on_update,  :proc   ],
      [ :after_validation_on_update,  :object ],
      [ :after_validation_on_update,  :block  ],
      [ :before_save,                 :string ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_update,               :string ],
      [ :before_update,               :proc   ],
      [ :before_update,               :object ],
      [ :before_update,               :block  ],
      [ :after_update,                :string ],
      [ :after_update,                :proc   ],
      [ :after_update,                :object ],
      [ :after_update,                :block  ],
      [ :after_save,                  :string ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ]
    ], david.history
  end

  def test_destroy
    david = CallbackDeveloper.find(1)
    david.destroy
    assert_equal [
      [ :after_find,            :string ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :string ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_destroy,              :string ],
      [ :before_destroy,              :proc   ],
      [ :before_destroy,              :object ],
      [ :before_destroy,              :block  ],
      [ :after_destroy,               :string ],
      [ :after_destroy,               :proc   ],
      [ :after_destroy,               :object ],
      [ :after_destroy,               :block  ]
    ], david.history
  end

  def test_delete
    david = CallbackDeveloper.find(1)
    CallbackDeveloper.delete(david.id)
    assert_equal [
      [ :after_find,            :string ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :string ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
    ], david.history
  end

  def test_before_save_returning_false
    david = ImmutableDeveloper.find(1)
    assert david.valid?
    assert !david.save
    assert_raises(ActiveRecord::RecordNotSaved) { david.save! }

    david = ImmutableDeveloper.find(1)
    david.salary = 10_000_000
    assert !david.valid?
    assert !david.save
    assert_raises(ActiveRecord::RecordInvalid) { david.save! }
  end

  def test_before_create_returning_false
    someone = CallbackCancellationDeveloper.new
    assert someone.valid?
    assert !someone.save
  end

  def test_before_destroy_returning_false
    david = ImmutableDeveloper.find(1)
    assert !david.destroy
    assert_not_nil ImmutableDeveloper.find_by_id(1)
  end

  def test_zzz_callback_returning_false # must be run last since we modify CallbackDeveloper
    david = CallbackDeveloper.find(1)
    CallbackDeveloper.before_validation proc { |model| model.history << [:before_validation, :returning_false]; return false }
    CallbackDeveloper.before_validation proc { |model| model.history << [:before_validation, :should_never_get_here] }
    david.save
    assert_equal [
      [ :after_find,            :string ],
      [ :after_find,            :proc   ],
      [ :after_find,            :object ],
      [ :after_find,            :block  ],
      [ :after_initialize,            :string ],
      [ :after_initialize,            :proc   ],
      [ :after_initialize,            :object ],
      [ :after_initialize,            :block  ],
      [ :before_validation,           :string ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :before_validation, :returning_false  ]
    ], david.history
  end

  def test_inheritence_of_callbacks
    parent = ParentDeveloper.new
    assert !parent.after_save_called
    parent.save
    assert parent.after_save_called

    child = ChildDeveloper.new
    assert !child.after_save_called
    child.save
    assert child.after_save_called
  end

end
