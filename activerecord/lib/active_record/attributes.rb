module ActiveRecord
  module Attributes

     # Returns true if the given attribute is in the attributes hash
     def has_attribute?(attr_name)
       _attributes.key?(attr_name)
     end

     # Returns an array of names for the attributes available on this object sorted alphabetically.
     def attribute_names
       _attributes.keys.sort!
     end

     # Returns a hash of all the attributes with their names as keys and the values of the attributes as values.
     def attributes
       attributes = _attributes.dup
       attributes.typecast! unless _attributes.frozen?
       attributes.to_h
     end

     protected

     # Not to be confused with the public #attributes method, which returns a typecasted Hash.
     def _attributes
       @attributes
     end

     def initialize_attribute_store(merge_attributes = nil)
       @attributes = ActiveRecord::Attributes::Store.new
       @attributes.merge!(merge_attributes) if merge_attributes
       @attributes.types.merge!(self.class.attribute_types)
       @attributes.aliases.merge!('id' => self.class.primary_key) unless 'id' == self.class.primary_key
       @attributes
     end

  end
end
