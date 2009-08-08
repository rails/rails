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
    #   #=> "Foo.find(params[:id])"
    #
    #   Datamapper::Generators::ActiveModel.find(Foo, "params[:id]")
    #   #=> "Foo.get(params[:id])"
    #
    # On initialization, the ActiveModel accepts the instance name that will
    # receive the calls:
    #
    #   builder = ActiveRecord::Generators::ActiveModel.new "@foo"
    #   builder.save #=> "@foo.save"
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
        raise NotImplementedError
      end

      # GET show
      # GET edit
      # PUT update
      # DELETE destroy
      def self.find(klass, params=nil)
        raise NotImplementedError
      end

      # GET new
      # POST create
      def self.build(klass, params=nil)
        raise NotImplementedError
      end

      # POST create
      def save
        raise NotImplementedError
      end

      # PUT update
      def update_attributes(params=nil)
        raise NotImplementedError
      end

      # POST create
      # PUT update
      def errors
        raise NotImplementedError
      end

      # DELETE destroy
      def destroy
        raise NotImplementedError
      end
    end
  end
end
