module ActiveModel
  # == Active Model Conversions
  #
  # Handles default conversions: to_model, to_key and to_param.
  #
  # Let's take for example this non persisted object.
  #
  #   class ContactMessage
  #     include ActiveModel::Conversion
  #
  #     # ContactMessage are never persisted in the DB
  #     def persisted?
  #       false
  #     end
  #   end
  #
  #   cm = ContactMessage.new
  #   cm.to_model == self # => true
  #   cm.to_key           # => nil
  #   cm.to_param         # => nil
  #
  module Conversion
    # If your object is already designed to implement all of the Active Model
    # you can use the default <tt>:to_model</tt> implementation, which simply
    # returns self.
    #
    # If your model does not act like an Active Model object, then you should
    # define <tt>:to_model</tt> yourself returning a proxy object that wraps
    # your object with Active Model compliant methods.
    def to_model
      self
    end

    # Returns an Enumerable of all key attributes if any is set, regardless
    # if the object is persisted or not.
    #
    # Note the default implementation uses persisted? just because all objects
    # in Ruby 1.8.x responds to <tt>:id</tt>.
    def to_key
      persisted? ? [id] : nil
    end

    # Returns a string representing the object's key suitable for use in URLs,
    # or nil if <tt>persisted?</tt> is false.
    def to_param
      persisted? ? to_key.join('-') : nil
    end
  end
end
