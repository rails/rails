require 'abstract_unit'

class CallbackDeveloper < ActiveRecord::Base
  class << self
    def table_name; 'developers' end

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

  # after_initialize and after_find may not be declared using class methods.
  # They are invoked only if instance methods have been defined.
  def after_initialize
    history << [:after_initialize, :method]
  end

  def after_find
    history << [:after_find, :method]
  end
end


class CallbacksTest < Test::Unit::TestCase
  def setup
    @developers = create_fixtures('developers')
  end

  def test_initialize
    david = CallbackDeveloper.new
    assert_equal [
      [ :after_initialize,            :method ]
    ], david.history
  end

  def test_find
    david = CallbackDeveloper.find(1)
    assert_equal [
      [ :after_find,                  :method ],
      [ :after_initialize,            :method ]
    ], david.history
  end

  def test_new_valid?
    david = CallbackDeveloper.new
    david.valid?
    assert_equal [
      [ :after_initialize,            :method ],
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
      [ :after_find,                  :method ],
      [ :after_initialize,            :method ],
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
      [ :after_initialize,            :method ],
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
      [ :after_find,                  :method ],
      [ :after_initialize,            :method ],
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
      [ :after_find,                  :method ],
      [ :after_initialize,            :method ],
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
      [ :after_find,                  :method ],
      [ :after_initialize,            :method ]
    ], david.history
  end
end
