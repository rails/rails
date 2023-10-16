# frozen_string_literal: true

module ActiveModel
  # = Active Model \Persistence
  module Persistence
    extend ActiveSupport::Concern

    module ClassMethods
      # Builds an object (or multiple objects), then calls +#save+ if the objects responds to +#save+.
      # The resulting object is returned whether the object was saved successfully or not.
      #
      # The +attributes+ parameter can be either a Hash or an Array of Hashes. These Hashes describe the
      # attributes on the objects that are to be created.
      #
      # ==== Examples
      #   # Create a single new object
      #   User.create(first_name: 'Jamie')
      #
      #   # Create an Array of new objects
      #   User.create([{ first_name: 'Jamie' }, { first_name: 'Jeremy' }])
      #
      #   # Create a single object and pass it into a block to set other attributes.
      #   User.create(first_name: 'Jamie') do |u|
      #     u.is_admin = false
      #   end
      #
      #   # Creating an Array of new objects using a block, where the block is executed for each object:
      #   User.create([{ first_name: 'Jamie' }, { first_name: 'Jeremy' }]) do |u|
      #     u.is_admin = false
      #   end
      def create(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create(attr, &block) }
        else
          object = new(attributes, &block)
          object.save if object.respond_to?(:save)
          object
        end
      end

      # Builds an object (or multiple objects), then calls +#save!+ if the objects responds to +#save!+.
      # The resulting object is returned whether the object was saved successfully or not.
      #
      # The +attributes+ parameter can be either a Hash or an Array of Hashes.
      # These describe which attributes to be created on the object, or
      # multiple objects when given an Array of Hashes.
      def create!(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create!(attr, &block) }
        else
          object = new(attributes, &block)
          object.save! if object.respond_to?(:save!)
          object
        end
      end
    end
  end
end
