module ActiveRecord
  module AttributeMethods
    # = Active Record Attribute Methods Before Type Cast
    #
    # <tt>ActiveRecord::AttributeMethods::BeforeTypeCast</tt> provides a way to
    # read the value of the attributes before typecasting and deserialization.
    #
    #   class Task < ActiveRecord::Base
    #   end
    #
    #   task = Task.new(id: '1', completed_on: '2012-10-21')
    #   task.id           # => 1
    #   task.completed_on # => Sun, 21 Oct 2012
    #
    #   task.attributes_before_type_cast
    #   # => {"id"=>"1", "completed_on"=>"2012-10-21", ... }
    #   task.read_attribute_before_type_cast('id')           # => "1"
    #   task.read_attribute_before_type_cast('completed_on') # => "2012-10-21"
    #
    # In addition to #read_attribute_before_type_cast and #attributes_before_type_cast,
    # it declares a method for all attributes with the <tt>*_before_type_cast</tt>
    # suffix.
    #
    #   task.id_before_type_cast           # => "1"
    #   task.completed_on_before_type_cast # => "2012-10-21"
    module BeforeTypeCast
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "_before_type_cast"
      end

      # Returns the value of the attribute identified by +attr_name+ before
      # typecasting and deserialization.
      #
      #   class Task < ActiveRecord::Base
      #   end
      #
      #   task = Task.new(id: '1', completed_on: '2012-10-21')
      #   task.read_attribute('id')                            # => 1
      #   task.read_attribute_before_type_cast('id')           # => '1'
      #   task.read_attribute('completed_on')                  # => Sun, 21 Oct 2012
      #   task.read_attribute_before_type_cast('completed_on') # => "2012-10-21"
      def read_attribute_before_type_cast(attr_name)
        @attributes[attr_name]
      end

      # Returns a hash of attributes before typecasting and deserialization.
      #
      #   class Task < ActiveRecord::Base
      #   end
      #
      #   task = Task.new(title: nil, is_done: true, completed_on: '2012-10-21')
      #   task.attributes
      #   # => {"id"=>nil, "title"=>nil, "is_done"=>true, "completed_on"=>Sun, 21 Oct 2012, "created_at"=>nil, "updated_at"=>nil}
      #   task.attributes_before_type_cast
      #   # => {"id"=>nil, "title"=>nil, "is_done"=>true, "completed_on"=>"2012-10-21", "created_at"=>nil, "updated_at"=>nil}
      def attributes_before_type_cast
        @attributes
      end

      private

      # Handle *_before_type_cast for method_missing.
      def attribute_before_type_cast(attribute_name)
        read_attribute_before_type_cast(attribute_name)
      end
    end
  end
end
