# frozen_string_literal: true

module Rails
  module Generators
    # ActiveModel is a class to be implemented by each ORM to allow Rails to
    # generate customized controller code.
    #
    # The API has the same methods as ActiveRecord, but each method returns a
    # string that matches the ORM API.
    #
    # For example:
    #
    #   ActiveRecord::Generators::ActiveModel.find(Foo, "params[:id]")
    #   # => "Foo.find(params[:id])"
    #
    #   DataMapper::Generators::ActiveModel.find(Foo, "params[:id]")
    #   # => "Foo.get(params[:id])"
    #
    # On initialization, the ActiveModel accepts the instance name that will
    # receive the calls:
    #
    #   builder = ActiveRecord::Generators::ActiveModel.new "@foo"
    #   builder.save # => "@foo.save"
    #
    # The only exception in ActiveModel for ActiveRecord is the use of self.build
    # instead of self.new.
    #
    class ActiveModel
      attr_reader :name

      def initialize(name)
        @name = name
      end

      # GET index
      def self.all(klass)
        "#{klass}.all"
      end

      # GET show
      # GET edit
      # PATCH/PUT update
      # DELETE destroy
      def self.find(klass, params = nil)
        "#{klass}.find(#{params})"
      end

      # GET new
      # POST create
      def self.build(klass, params = nil)
        if params
          "#{klass}.new(#{params})"
        else
          "#{klass}.new"
        end
      end

      # POST create
      def save
        "#{name}.save"
      end

      # PATCH/PUT update
      def update(params = nil)
        "#{name}.update(#{params})"
      end

      # POST create
      # PATCH/PUT update
      def errors
        "#{name}.errors"
      end

      # DELETE destroy
      def destroy
        "#{name}.destroy"
      end
    end
  end
end
