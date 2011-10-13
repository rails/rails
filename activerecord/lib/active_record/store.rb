module ActiveRecord
  # Store gives you a thin wrapper around serialize for the purpose of storing hashes in a single column.
  # It's like a simple key/value store backed into your record when you don't care about being able to
  # query that store outside the context of a single record.
  #
  # You can then declare accessors to this store that are then accessible just like any other attribute
  # of the model. This is very helpful for easily exposing store keys to a form or elsewhere that's
  # already built around just accessing attributes on the model.
  #
  # Make sure that you declare the database column used for the serialized store as a text, so there's
  # plenty of room.
  #
  # Examples:
  #
  #   class User < ActiveRecord::Base
  #     store :settings, accessors: [ :color, :homepage ]
  #   end
  #   
  #   u = User.new(color: 'black', homepage: '37signals.com')
  #   u.color                          # Accessor stored attribute
  #   u.settings[:country] = 'Denmark' # Any attribute, even if not specified with an accessor
  #
  #   # Add additional accessors to an existing store through store_accessor
  #   class SuperUser < User
  #     store_accessor :settings, :privileges, :servants
  #   end
  module Store
    extend ActiveSupport::Concern
  
    module ClassMethods
      def store(store_attribute, options = {})
        serialize store_attribute, Hash
        store_accessor(store_attribute, options[:accessors]) if options.has_key? :accessors
      end

      def store_accessor(store_attribute, *keys)
        Array(keys).flatten.each do |key|
          define_method("#{key}=") do |value|
            send(store_attribute)[key] = value
          end
    
          define_method(key) do
            send(store_attribute)[key]
          end
        end
      end
    end
  end
end