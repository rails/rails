module ActiveRecord
  module AttributeMethods
    # = Active Record Attribute Methods Before Type Cast
    #
    # ActiveRecord::AttributeMethods::BeforeTypeCast provides a way to
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
        attribute_method_suffix "_came_from_user?"
      end

      # Returns the value of the attribute identified by +attr_name+ before
      # typecasting and deserialization.
      #
      #   class Task < ActiveRecord::Base
      #     attribute :start_on, :date, default: -> { Date.new(2011, 10, 21) }
      #   end
      #
      #   task = Task.new(id: '1', completed_on: '2012-10-21')
      #   task.read_attribute('id')                            # => 1
      #   task.read_attribute_before_type_cast('id')           # => '1'
      #   task.read_attribute('completed_on')                  # => Sun, 21 Oct 2012
      #   task.read_attribute('start_on')                      # => Fri, 21 Oct 2011
      #   task.read_attribute_before_type_cast('completed_on') # => "2012-10-21"
      #   task.read_attribute_before_type_cast(:completed_on)  # => "2012-10-21"
      #   task.read_attribute_before_type_cast('start_on')      # => "2011-10-21"
      #   task.read_attribute_before_type_cast(:start_on)      # => "2011-10-21"
      def read_attribute_before_type_cast(attr_name)
        value_before_type_cast = @attributes[attr_name.to_s].value_before_type_cast
        value_before_type_cast.kind_of?(Proc) ? value_before_type_cast.call : value_before_type_cast
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
        @attributes.values_before_type_cast
      end

      private

      # Handle *_before_type_cast for method_missing.
      def attribute_before_type_cast(attribute_name)
        read_attribute_before_type_cast(attribute_name)
      end

      def attribute_came_from_user?(attribute_name)
        @attributes[attribute_name].came_from_user?
      end
    end
  end
end
