# frozen_string_literal: true

module ActiveModel
  # = Active Model \Base
  #
  # Base provides subclasses with an Active Record-inspired
  # interface to execute code with familiar methods like +.create+, +#save+, and
  # +#update+. It includes the API module transitively through the Model module,
  # so it's designed to integrate with Action Pack and Action View out of the box.
  #
  # Similar to the convention for applications to define an
  # <tt>ApplicationRecord</tt> that inherits <tt>ActiveRecord::Base</tt>, it's
  # also conventional for applications to define an <tt>ApplicationModel</tt>
  # that inherits from Base:
  #
  #   # app/models/application_model.rb
  #
  #   class ApplicationModel < ActiveModel::Base
  #   end
  #
  # Unlike other facets of Active Model, Base is a Class instead of a Module.
  # Once classes have inherited from Base, they only need to define a +#save!+.
  # For example, consider a <tt>Session</tt> model responsible for authenticating a
  # <tt>User</tt>  with +email+ and +password+ credentials:
  #
  #   # app/models/session.rb
  #
  #   class Session < ApplicationModel
  #     attr_accessor :email, :password, :request
  #
  #     validates :email, :password, presence: true
  #
  #     def save!
  #       if (user = User.authenticate_by(email: email, password: password))
  #         request.cookies[:signed_user_id] = user.signed_id
  #       else
  #         errors.add(:base, :invalid)
  #
  #         raise ActiveModel::ValidationError.new(self)
  #       end
  #     end
  #   end
  #
  # NOTE: This implementation is intended for demonstration purposes only, and
  # is not meant to be used in a real application.
  #
  # By defining +#save!+, the +Session+ class gains access to other methods
  # provided by Base, like +create!+ and +create+, +update!+ and +update+,
  # +persisted?+ and +new_model?+, and all of the other utilities provided by
  # Model, API, and Conversion.
  class Base
    class << self
      # Creates an object (or multiple objects) and saves them, if validations pass.
      # The resulting object is returned whether the object was saved successfully or not.
      #
      # The +attributes+ parameter can be either a Hash or an Array of Hashes. These Hashes describe the
      # attributes on the objects that are to be created.
      #
      # ==== Examples
      #   # Create a single new object
      #   User.create(first_name: "Jamie")
      #
      #   # Create an Array of new objects
      #   User.create([{ first_name: "Jamie" }, { first_name: "Jeremy" }])
      #
      #   # Create a single object and pass it into a block to set other attributes.
      #   User.create(first_name: "Jamie") do |u|
      #     u.is_admin = false
      #   end
      #
      #   # Creating an Array of new objects using a block, where the block is executed for each object:
      #   User.create([{ first_name: "Jamie" }, { first_name: "Jeremy" }]) do |u|
      #     u.is_admin = false
      #   end
      def create(attributes = nil, &block)
        case attributes
        when Array then attributes.map { |attr| create(attr, &block) }
        else new(attributes, &block).tap(&:save)
        end
      end

      # Creates an object (or multiple objects) and saves it,
      # if validations pass. Raises a ValidationError error if validations fail,
      # unlike Base#create.
      #
      # The +attributes+ parameter can be either a Hash or an Array of Hashes.
      # These describe which attributes to be created on the object, or
      # multiple objects when given an Array of Hashes.
      def create!(attributes = nil, &block)
        case attributes
        when Array then attributes.map { |attr| create!(attr, &block) }
        else new(attributes, &block).tap(&:save!)
        end
      end

      # Builds an object (or multiple objects) and returns either the built object or a list of built
      # objects.
      #
      # The +attributes+ parameter can be either a Hash or an Array of Hashes. These Hashes describe the
      # attributes on the objects that are to be built.
      #
      # ==== Examples
      #   # Build a single new object
      #   User.build(first_name: "Jamie")
      #
      #   # Build an Array of new objects
      #   User.build([{ first_name: "Jamie" }, { first_name: "Jeremy" }])
      #
      #   # Build a single object and pass it into a block to set other attributes.
      #   User.build(first_name: "Jamie") do |u|
      #     u.is_admin = false
      #   end
      #
      #   # Building an Array of new objects using a block, where the block is executed for each object:
      #   User.build([{ first_name: "Jamie" }, { first_name: "Jeremy" }]) do |u|
      #     u.is_admin = false
      #   end
      def build(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| build(attr, &block) }
        else
          new(attributes, &block)
        end
      end

      def inherited(subclass)
        subclass.singleton_class.define_method :method_added do |method_name|
          return if defines_save_override

          if method_name == :save!
            alias_method :call, :save!
            remove_method :save!
            self.defines_save_override = true
          end
        end
      end
    end

    module Callbacks
      extend ActiveSupport::Concern

      included do
        include ActiveModel::Validations::Callbacks

        define_model_callbacks :initialize, only: :after
        define_model_callbacks :save
      end

      module ClassMethods
        ##
        # :method: after_initialize
        #
        # :call-seq: after_initialize(*args, &block)
        #
        # Registers a callback to be called after a model is instantiated. See
        # Callbacks for more information.

        ##
        # :method: before_validation
        #
        # :call-seq: before_validation(*args, &block)
        #
        # Registers a callback to be called before a model is validated. See
        # Callbacks for more information.

        ##
        # :method: after_validation
        #
        # :call-seq: after_validation(*args, &block)
        #
        # Registers a callback to be called after a model is validated. See
        # Callbacks for more information.

        ##
        # :method: before_save
        #
        # :call-seq: before_save(*args, &block)
        #
        # Registers a callback to be called before a model is saved. See
        # Callbacks for more information.

        ##
        # :method: around_save
        #
        # :call-seq: around_save(*args, &block)
        #
        # Registers a callback to be called around the save of a model. See
        # Callbacks for more information.

        ##
        # :method: after_save
        #
        # :call-seq: after_save(*args, &block)
        #
        # Registers a callback to be called after a model is saved. See
        # Callbacks for more information.
      end
    end

    include ActiveModel::Model
    include ActiveModel::Base::Callbacks

    class_attribute :validation_exceptions, instance_accessor: false, default: [ValidationError]
    class_attribute :defines_save_override, instance_accessor: false, default: false

    around_save do |_, block|
      @persisted = false
      block.call
      @persisted = true
    end

    # New objects can be instantiated as either empty (pass no construction parameter) or pre-set with
    # attributes but not yet saved (pass a hash with key names matching the associated attribute names).
    # In both instances, valid attribute keys are determined by the attribute names --
    # hence you can't have attributes that have not been declared.
    #
    # ==== Example
    #   # Instantiates a single new object with attributes
    #   User.new(first_name: "Jamie")
    #
    #   # Instantiates a single new object with a block
    #   User.new { |user| user.first_name: "Jamie" }
    #
    #   # Instantiates a single new object with attributes and a block
    #   User.new(first_name: "Jamie") { |user| user.first_name.upcase! }
    def initialize(attributes = nil, &block)
      run_callbacks :initialize do
        super(attributes)
        tap { yield_self(&block) if block }
      end
    end

    # Carry out the model's responsibility. Returns +true+ on success. Raises
    # ValidationError on failure.
    #
    # Override +#save!+ in subclasses:
    #
    #   attr_accessor :email, :password, :request
    #
    #   def save!
    #     if (user = User.authenticate_by(email: email, password: password)
    #       request.cookies[:signed_user_id] = user.signed_user_id
    #     else
    #       errors.add(:base, :invalid)
    #
    #       raise ActiveModel::ValidationError.new(self)
    #     end
    #   end
    #
    # ==== Options
    #
    # * +:validate+ By default, #save! always runs validations. If any of them fail ActiveModel::ValidationError gets raised, and the model won't be saved. However, if you supply
    # <tt>validate: false</tt>, validations are bypassed altogether. See Validations for more information.
    # * +:context+ Forwarded to the call to #validate!. See Validations for more information
    #
    # ==== Example
    #
    #   session = Session.new(email: "user@example.com", password: "")
    #   session.save! # => raises ActiveModel::ValidationError
    #
    #   # skip validations
    #   session.save!(validate: true) # => raises ActiveModel::ValidationError
    #   session.save!(validate: false) # => true
    #
    #   # with validation contexts
    #   session = Session.new(email: "", password: "secret")
    #   session.save!(context: :sign_in) # => raises ActiveModel::ValidationError
    #   session.save!(context: :permission_check) # => true
    def save!(validate: true, context: nil)
      run_callbacks :save do
        validate!(context) if validate
        call
        true
      end
    end

    def call # :nodoc:
    end

    ##
    # :call-seq:
    #   save(validate: true, context: nil)
    #
    # Calls +#save!+. Returns +true+ on success. Rescues from ValidationError
    # and returns +false+
    #
    # ==== Example
    #
    #   user = User.new(email: "user@example.com")
    #   user.save # => true
    #
    #   # skipping validations
    #   user = User.new(email: "")
    #   user.save(validate: true) # => false
    #   user.save(validate: false) # => true
    #
    #   # with validation contexts
    #   session = Session.new(email: "", password: "secret")
    #   session.save(context: :sign_in) # => false
    #   session.save(context: :permission_check) # => true
    def save(...)
      rescue_from Base.validation_exceptions do
        save!(...)
      end
    end

    ##
    # :call-seq:
    #   update(attributes)
    #
    # Assigns attributes, then calls +#save!+. Returns +true+ on success. Rescues from ValidationError
    # and returns +false+
    #
    # ==== Example
    #
    #   user = User.new
    #   user.update(email: "user@example.com") # => true
    def update(...)
      rescue_from Base.validation_exceptions do
        update!(...)
      end
    end

    ##
    # :call-seq:
    #   update!(attributes)
    #
    # Assigns attributes, then calls +#save!+. Returns +true+ on success. Raises
    # ValidationError on failure.
    #
    # ==== Example
    #
    #   user = User.new
    #   user.update(email: "user@example.com") # => true
    #
    #   user.update!(email: "") # => raises ActiveModel::ValidationError
    def update!(...)
      assign_attributes(...)
      save!
    end

    # Returns whether or not the last call to +#save!+ succeeded.
    # Each time +#save!+ is called, Base subclasses will reset their persistence
    # state
    #
    # Named as such to integrate with Action Pack and Action View through the
    # Conversion module.
    #
    # ==== Example
    #
    #   user = User.new email: ""
    #   user.save # => false
    #   user.persisted? # => false
    #
    #   user.email = "user@example.com"
    #   user.save # => true
    #   user.persisted? # => true
    #
    #   user.email = nil
    #   user.save # => false
    #   user.persisted? # => false
    def persisted?
      @persisted
    end

    # Returns the inverse of +#persisted?+
    def new_model?
      !persisted?
    end
    alias_method :new_record?, :new_model?

    # Not intended to be invoked directly. Override the definition to customize
    # the errors handled during +#save!+.
    #
    # Rescues from ValidationError by default. When Active Record is loaded,
    # also rescues from ActiveRecord::RecordInvalid.
    #
    #   # add to existing exceptions
    #   def rescue_from(failures, &block)
    #     block.call
    #     true
    #   rescue MyException, *failures
    #     false
    #   end
    #
    #   # treat certain exceptions as success
    #   def rescue_from(failures, &block)
    #     block.call
    #     true
    #   rescue MyException
    #     true
    #   rescue *failures
    #     false
    #   end
    #
    #   # ignroe default exceptions
    #   def rescue_from(_, &block)
    #     block.call
    #     true
    #   rescue MyException
    #     false
    #   end
    #
    def rescue_from(failures, &block)
      block.call
      true
    rescue *failures
      false
    end
  end

  ActiveSupport.run_load_hooks(:active_model_base, Base)
end
