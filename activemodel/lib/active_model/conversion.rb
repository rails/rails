require 'active_support/concern'
require 'active_support/inflector'

module ActiveModel
  # == Active Model Conversions
  #
  # Handles default conversions: to_model, to_key, to_param, and to_partial_path.
  #
  # Let's take for example this non-persisted object.
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
  #   cm.to_path          # => "contact_messages/contact_message"
  #
  module Conversion
    extend ActiveSupport::Concern

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

    # Returns a string identifying the path associated with the object.
    # ActionPack uses this to find a suitable partial to represent the object.
    def to_partial_path
      self.class._to_partial_path
    end

    module ClassMethods #:nodoc:
      # Provide a class level cache for the to_path. This is an
      # internal method and should not be accessed directly.
      def _to_partial_path #:nodoc:
        @_to_partial_path ||= begin
          element = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(self))
          collection = ActiveSupport::Inflector.tableize(self)
          "#{collection}/#{element}".freeze
        end
      end
    end
  end
end
