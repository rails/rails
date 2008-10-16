require 'observer'

module ActiveRecord
  # Callbacks are hooks into the lifecycle of an Active Record object that allow you to trigger logic
  # before or after an alteration of the object state. This can be used to make sure that associated and
  # dependent objects are deleted when +destroy+ is called (by overwriting +before_destroy+) or to massage attributes
  # before they're validated (by overwriting +before_validation+). As an example of the callbacks initiated, consider
  # the <tt>Base#save</tt> call for a new record:
  #
  # * (-) <tt>save</tt>
  # * (-) <tt>valid</tt>
  # * (1) <tt>before_validation</tt>
  # * (2) <tt>before_validation_on_create</tt>
  # * (-) <tt>validate</tt>
  # * (-) <tt>validate_on_create</tt>
  # * (3) <tt>after_validation</tt>
  # * (4) <tt>after_validation_on_create</tt>
  # * (5) <tt>before_save</tt>
  # * (6) <tt>before_create</tt>
  # * (-) <tt>create</tt>
  # * (7) <tt>after_create</tt>
  # * (8) <tt>after_save</tt>
  #
  # That's a total of eight callbacks, which gives you immense power to react and prepare for each state in the
  # Active Record lifecycle. The sequence for calling <tt>Base#save</tt> an existing record is similar, except that each 
  # <tt>_on_create</tt> callback is replaced by the corresponding <tt>_on_update</tt> callback.
  #
  # Examples:
  #   class CreditCard < ActiveRecord::Base
  #     # Strip everything but digits, so the user can specify "555 234 34" or
  #     # "5552-3434" or both will mean "55523434"
  #     def before_validation_on_create
  #       self.number = number.gsub(/[^0-9]/, "") if attribute_present?("number")
  #     end
  #   end
  #
  #   class Subscription < ActiveRecord::Base
  #     before_create :record_signup
  #
  #     private
  #       def record_signup
  #         self.signed_up_on = Date.today
  #       end
  #   end
  #
  #   class Firm < ActiveRecord::Base
  #     # Destroys the associated clients and people when the firm is destroyed
  #     before_destroy { |record| Person.destroy_all "firm_id = #{record.id}"   }
  #     before_destroy { |record| Client.destroy_all "client_of = #{record.id}" }
  #   end
  #
  # == Inheritable callback queues
  #
  # Besides the overwritable callback methods, it's also possible to register callbacks through the use of the callback macros.
  # Their main advantage is that the macros add behavior into a callback queue that is kept intact down through an inheritance
  # hierarchy. Example:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy :destroy_author
  #   end
  #
  #   class Reply < Topic
  #     before_destroy :destroy_readers
  #   end
  #
  # Now, when <tt>Topic#destroy</tt> is run only +destroy_author+ is called. When <tt>Reply#destroy</tt> is run, both +destroy_author+ and
  # +destroy_readers+ are called. Contrast this to the situation where we've implemented the save behavior through overwriteable
  # methods:
  #
  #   class Topic < ActiveRecord::Base
  #     def before_destroy() destroy_author end
  #   end
  #
  #   class Reply < Topic
  #     def before_destroy() destroy_readers end
  #   end
  #
  # In that case, <tt>Reply#destroy</tt> would only run +destroy_readers+ and _not_ +destroy_author+. So, use the callback macros when
  # you want to ensure that a certain callback is called for the entire hierarchy, and use the regular overwriteable methods
  # when you want to leave it up to each descendent to decide whether they want to call +super+ and trigger the inherited callbacks.
  #
  # *IMPORTANT:* In order for inheritance to work for the callback queues, you must specify the callbacks before specifying the
  # associations. Otherwise, you might trigger the loading of a child before the parent has registered the callbacks and they won't
  # be inherited.
  #
  # == Types of callbacks
  #
  # There are four types of callbacks accepted by the callback macros: Method references (symbol), callback objects,
  # inline methods (using a proc), and inline eval methods (using a string). Method references and callback objects are the
  # recommended approaches, inline methods using a proc are sometimes appropriate (such as for creating mix-ins), and inline
  # eval methods are deprecated.
  #
  # The method reference callbacks work by specifying a protected or private method available in the object, like this:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy :delete_parents
  #
  #     private
  #       def delete_parents
  #         self.class.delete_all "parent_id = #{id}"
  #       end
  #   end
  #
  # The callback objects have methods named after the callback called with the record as the only parameter, such as:
  #
  #   class BankAccount < ActiveRecord::Base
  #     before_save      EncryptionWrapper.new("credit_card_number")
  #     after_save       EncryptionWrapper.new("credit_card_number")
  #     after_initialize EncryptionWrapper.new("credit_card_number")
  #   end
  #
  #   class EncryptionWrapper
  #     def initialize(attribute)
  #       @attribute = attribute
  #     end
  #
  #     def before_save(record)
  #       record.credit_card_number = encrypt(record.credit_card_number)
  #     end
  #
  #     def after_save(record)
  #       record.credit_card_number = decrypt(record.credit_card_number)
  #     end
  #
  #     alias_method :after_find, :after_save
  #
  #     private
  #       def encrypt(value)
  #         # Secrecy is committed
  #       end
  #
  #       def decrypt(value)
  #         # Secrecy is unveiled
  #       end
  #   end
  #
  # So you specify the object you want messaged on a given callback. When that callback is triggered, the object has
  # a method by the name of the callback messaged.
  #
  # The callback macros usually accept a symbol for the method they're supposed to run, but you can also pass a "method string",
  # which will then be evaluated within the binding of the callback. Example:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy 'self.class.delete_all "parent_id = #{id}"'
  #   end
  #
  # Notice that single quotes (') are used so the <tt>#{id}</tt> part isn't evaluated until the callback is triggered. Also note that these
  # inline callbacks can be stacked just like the regular ones:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy 'self.class.delete_all "parent_id = #{id}"',
  #                    'puts "Evaluated after parents are destroyed"'
  #   end
  #
  # == The +after_find+ and +after_initialize+ exceptions
  #
  # Because +after_find+ and +after_initialize+ are called for each object found and instantiated by a finder, such as <tt>Base.find(:all)</tt>, we've had
  # to implement a simple performance constraint (50% more speed on a simple test case). Unlike all the other callbacks, +after_find+ and
  # +after_initialize+ will only be run if an explicit implementation is defined (<tt>def after_find</tt>). In that case, all of the
  # callback types will be called.
  #
  # == <tt>before_validation*</tt> returning statements
  #
  # If the returning value of a +before_validation+ callback can be evaluated to +false+, the process will be aborted and <tt>Base#save</tt> will return +false+.
  # If Base#save! is called it will raise a ActiveRecord::RecordInvalid exception.
  # Nothing will be appended to the errors object.
  #
  # == Canceling callbacks
  #
  # If a <tt>before_*</tt> callback returns +false+, all the later callbacks and the associated action are cancelled. If an <tt>after_*</tt> callback returns
  # +false+, all the later callbacks are cancelled. Callbacks are generally run in the order they are defined, with the exception of callbacks
  # defined as methods on the model, which are called last.
  #
  # == Transactions
  #
  # The entire callback chain of a +save+, <tt>save!</tt>, or +destroy+ call runs
  # within a transaction. That includes <tt>after_*</tt> hooks. If everything
  # goes fine a COMMIT is executed once the chain has been completed.
  #
  # If a <tt>before_*</tt> callback cancels the action a ROLLBACK is issued. You
  # can also trigger a ROLLBACK raising an exception in any of the callbacks,
  # including <tt>after_*</tt> hooks. Note, however, that in that case the client
  # needs to be aware of it because an ordinary +save+ will raise such exception
  # instead of quietly returning +false+.
  module Callbacks
    CALLBACKS = %w(
      after_find after_initialize before_save after_save before_create after_create before_update after_update before_validation
      after_validation before_validation_on_create after_validation_on_create before_validation_on_update
      after_validation_on_update before_destroy after_destroy
    )

    def self.included(base) #:nodoc:
      base.extend Observable

      [:create_or_update, :valid?, :create, :update, :destroy].each do |method|
        base.send :alias_method_chain, method, :callbacks
      end

      base.send :include, ActiveSupport::Callbacks
      base.define_callbacks *CALLBACKS
    end

    # Is called when the object was instantiated by one of the finders, like <tt>Base.find</tt>.
    #def after_find() end

    # Is called after the object has been instantiated by a call to <tt>Base.new</tt>.
    #def after_initialize() end

    # Is called _before_ <tt>Base.save</tt> (regardless of whether it's a +create+ or +update+ save).
    def before_save() end

    # Is called _after_ <tt>Base.save</tt> (regardless of whether it's a +create+ or +update+ save).
    # Note that this callback is still wrapped in the transaction around +save+. For example, if you
    # invoke an external indexer at this point it won't see the changes in the database.
    #
    #  class Contact < ActiveRecord::Base
    #    after_save { logger.info( 'New contact saved!' ) }
    #  end
    def after_save()  end
    def create_or_update_with_callbacks #:nodoc:
      return false if callback(:before_save) == false
      result = create_or_update_without_callbacks
      callback(:after_save)
      result
    end
    private :create_or_update_with_callbacks

    # Is called _before_ <tt>Base.save</tt> on new objects that haven't been saved yet (no record exists).
    def before_create() end

    # Is called _after_ <tt>Base.save</tt> on new objects that haven't been saved yet (no record exists).
    # Note that this callback is still wrapped in the transaction around +save+. For example, if you
    # invoke an external indexer at this point it won't see the changes in the database.
    def after_create() end
    def create_with_callbacks #:nodoc:
      return false if callback(:before_create) == false
      result = create_without_callbacks
      callback(:after_create)
      result
    end
    private :create_with_callbacks

    # Is called _before_ <tt>Base.save</tt> on existing objects that have a record.
    def before_update() end

    # Is called _after_ <tt>Base.save</tt> on existing objects that have a record.
    # Note that this callback is still wrapped in the transaction around +save+. For example, if you
    # invoke an external indexer at this point it won't see the changes in the database.
    def after_update() end

    def update_with_callbacks(*args) #:nodoc:
      return false if callback(:before_update) == false
      result = update_without_callbacks(*args)
      callback(:after_update)
      result
    end
    private :update_with_callbacks

    # Is called _before_ <tt>Validations.validate</tt> (which is part of the <tt>Base.save</tt> call).
    def before_validation() end

    # Is called _after_ <tt>Validations.validate</tt> (which is part of the <tt>Base.save</tt> call).
    def after_validation() end

    # Is called _before_ <tt>Validations.validate</tt> (which is part of the <tt>Base.save</tt> call) on new objects
    # that haven't been saved yet (no record exists).
    def before_validation_on_create() end

    # Is called _after_ <tt>Validations.validate</tt> (which is part of the <tt>Base.save</tt> call) on new objects
    # that haven't been saved yet (no record exists).
    def after_validation_on_create()  end

    # Is called _before_ <tt>Validations.validate</tt> (which is part of the <tt>Base.save</tt> call) on
    # existing objects that have a record.
    def before_validation_on_update() end

    # Is called _after_ <tt>Validations.validate</tt> (which is part of the <tt>Base.save</tt> call) on
    # existing objects that have a record.
    def after_validation_on_update()  end

    def valid_with_callbacks? #:nodoc:
      return false if callback(:before_validation) == false
      if new_record? then result = callback(:before_validation_on_create) else result = callback(:before_validation_on_update) end
      return false if false == result

      result = valid_without_callbacks?

      callback(:after_validation)
      if new_record? then callback(:after_validation_on_create) else callback(:after_validation_on_update) end

      return result
    end

    # Is called _before_ <tt>Base.destroy</tt>.
    #
    # Note: If you need to _destroy_ or _nullify_ associated records first,
    # use the <tt>:dependent</tt> option on your associations.
    def before_destroy() end

    # Is called _after_ <tt>Base.destroy</tt> (and all the attributes have been frozen).
    #
    #  class Contact < ActiveRecord::Base
    #    after_destroy { |record| logger.info( "Contact #{record.id} was destroyed." ) }
    #  end
    def after_destroy()  end
    def destroy_with_callbacks #:nodoc:
      return false if callback(:before_destroy) == false
      result = destroy_without_callbacks
      callback(:after_destroy)
      result
    end

    private
      def callback(method)
        result = run_callbacks(method) { |result, object| false == result }

        if result != false && respond_to_without_attributes?(method)
          result = send(method)
        end

        notify(method)

        return result
      end

      def notify(method) #:nodoc:
        self.class.changed
        self.class.notify_observers(method, self)
      end
  end
end
