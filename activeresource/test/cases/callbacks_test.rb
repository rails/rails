require 'abstract_unit'
require 'active_support/core_ext/hash/conversions'

class Developer < ActiveResource::Base
  self.site = 'http://37s.sunrise.i:3000'

  class << self
    def callback_string(callback_method)
      "history << [#{callback_method.to_sym.inspect}, :string]"
    end

    def callback_proc(callback_method)
      Proc.new { |model| model.history << [callback_method, :proc] }
    end

    def define_callback_method(callback_method)
      define_method(callback_method) do
        self.history << [callback_method, :method]
      end
      send(callback_method, :"#{callback_method}")
    end

    def callback_object(callback_method)
      klass = Class.new
      klass.send(:define_method, callback_method) do |model|
        model.history << [callback_method, :object]
      end
      klass.new
    end
  end

  ActiveResource::Callbacks::CALLBACKS.each do |callback_method|
    next if callback_method.to_s =~ /^around_/
    define_callback_method(callback_method)
    send(callback_method, callback_string(callback_method))
    send(callback_method, callback_proc(callback_method))
    send(callback_method, callback_object(callback_method))
    send(callback_method) { |model| model.history << [callback_method, :block] }
  end

  def history
    @history ||= []
  end
end

class CallbacksTest < ActiveModel::TestCase
  def setup
    @developer_attrs = {:id => 1, :name => "Guillermo", :salary => 100_000}
    @developer = {"developer" => @developer_attrs}.to_json
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post   '/developers.json',   {}, @developer, 201, 'Location' => '/developers/1.json'
      mock.get    '/developers/1.json', {}, @developer
      mock.put    '/developers/1.json', {}, nil, 204
      mock.delete '/developers/1.json', {}, nil, 200
    end
  end

  def test_valid?
    developer = Developer.new
    developer.valid?
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :string ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :string ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
    ], developer.history
  end

  def test_create
    developer = Developer.create(@developer_attrs)
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :string ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :string ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :before_save,                 :method ],
      [ :before_save,                 :string ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_create,               :method ],
      [ :before_create,               :string ],
      [ :before_create,               :proc   ],
      [ :before_create,               :object ],
      [ :before_create,               :block  ],
      [ :after_create,                :method ],
      [ :after_create,                :string ],
      [ :after_create,                :proc   ],
      [ :after_create,                :object ],
      [ :after_create,                :block  ],
      [ :after_save,                  :method ],
      [ :after_save,                  :string ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ]
    ], developer.history
  end

  def test_update
    developer = Developer.find(1)
    developer.save
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :string ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :string ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :before_save,                 :method ],
      [ :before_save,                 :string ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_update,               :method ],
      [ :before_update,               :string ],
      [ :before_update,               :proc   ],
      [ :before_update,               :object ],
      [ :before_update,               :block  ],
      [ :after_update,                :method ],
      [ :after_update,                :string ],
      [ :after_update,                :proc   ],
      [ :after_update,                :object ],
      [ :after_update,                :block  ],
      [ :after_save,                  :method ],
      [ :after_save,                  :string ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ]
    ], developer.history
  end

  def test_destroy
    developer = Developer.find(1)
    developer.destroy
    assert_equal [
      [ :before_destroy,              :method ],
      [ :before_destroy,              :string ],
      [ :before_destroy,              :proc   ],
      [ :before_destroy,              :object ],
      [ :before_destroy,              :block  ],
      [ :after_destroy,               :method ],
      [ :after_destroy,               :string ],
      [ :after_destroy,               :proc   ],
      [ :after_destroy,               :object ],
      [ :after_destroy,               :block  ]
    ], developer.history
  end

  def test_delete
    developer = Developer.find(1)
    Developer.delete(developer.id)
    assert_equal [], developer.history
  end
end
