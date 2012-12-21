require 'thread_safe'
require 'active_support/concern'
require 'active_support/descendants_tracker'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/kernel/singleton_class'

module ActiveSupport
  # Callbacks are code hooks that are run at key points in an object's lifecycle.
  # The typical use case is to have a base class define a set of callbacks
  # relevant to the other functionality it supplies, so that subclasses can
  # install callbacks that enhance or modify the base functionality without
  # needing to override or redefine methods of the base class.
  #
  # Mixing in this module allows you to define the events in the object's
  # lifecycle that will support callbacks (via +ClassMethods.define_callbacks+),
  # set the instance methods, procs, or callback objects to be called (via
  # +ClassMethods.set_callback+), and run the installed callbacks at the
  # appropriate times (via +run_callbacks+).
  #
  # Three kinds of callbacks are supported: before callbacks, run before a
  # certain event; after callbacks, run after the event; and around callbacks,
  # blocks that surround the event, triggering it when they yield. Callback code
  # can be contained in instance methods, procs or lambdas, or callback objects
  # that respond to certain predetermined methods. See +ClassMethods.set_callback+
  # for details.
  #
  #   class Record
  #     include ActiveSupport::Callbacks
  #     define_callbacks :save
  #
  #     def save
  #       run_callbacks :save do
  #         puts "- save"
  #       end
  #     end
  #   end
  #
  #   class PersonRecord < Record
  #     set_callback :save, :before, :saving_message
  #     def saving_message
  #       puts "saving..."
  #     end
  #
  #     set_callback :save, :after do |object|
  #       puts "saved"
  #     end
  #   end
  #
  #   person = PersonRecord.new
  #   person.save
  #
  # Output:
  #   saving...
  #   - save
  #   saved
  module Callbacks
    extend Concern

    included do
      extend ActiveSupport::DescendantsTracker
    end

    # Runs the callbacks for the given event.
    #
    # Calls the before and around callbacks in the order they were set, yields
    # the block (if given one), and then runs the after callbacks in reverse
    # order.
    #
    # If the callback chain was halted, returns +false+. Otherwise returns the
    # result of the block, or +true+ if no block is given.
    #
    #   run_callbacks :save do
    #     save
    #   end
    def run_callbacks(kind, &block)
      runner_name = self.class.__define_callbacks(kind, self)
      send(runner_name, &block)
    end

    private

    # A hook invoked everytime a before callback is halted.
    # This can be overridden in AS::Callback implementors in order
    # to provide better debugging/logging.
    def halted_callback_hook(filter)
    end

    class Callback #:nodoc:#
      @@_callback_sequence = 0

      attr_accessor :chain, :filter, :kind, :options, :klass, :raw_filter

      def initialize(chain, filter, kind, options, klass)
        @chain, @kind, @klass = chain, kind, klass
        deprecate_per_key_option(options)
        normalize_options!(options)

        @raw_filter, @options = filter, options
        @filter               = _compile_filter(filter)
        recompile_options!
      end

      def deprecate_per_key_option(options)
        if options[:per_key]
          raise NotImplementedError, ":per_key option is no longer supported. Use generic :if and :unless options instead."
        end
      end

      def clone(chain, klass)
        obj                  = super()
        obj.chain            = chain
        obj.klass            = klass
        obj.options          = @options.dup
        obj.options[:if]     = @options[:if].dup
        obj.options[:unless] = @options[:unless].dup
        obj
      end

      def normalize_options!(options)
        options[:if] = Array(options[:if])
        options[:unless] = Array(options[:unless])
      end

      def name
        chain.name
      end

      def next_id
        @@_callback_sequence += 1
      end

      def matches?(_kind, _filter)
        @kind == _kind && @filter == _filter
      end

      def duplicates?(other)
        matches?(other.kind, other.filter)
      end

      def _update_filter(filter_options, new_options)
        filter_options[:if].concat(Array(new_options[:unless])) if new_options.key?(:unless)
        filter_options[:unless].concat(Array(new_options[:if])) if new_options.key?(:if)
      end

      def recompile!(_options)
        deprecate_per_key_option(_options)
        _update_filter(self.options, _options)

        recompile_options!
      end

      # Wraps code with filter
      def apply(code)
        case @kind
        when :before
          <<-RUBY_EVAL
            if !halted && #{@compiled_options}
              # This double assignment is to prevent warnings in 1.9.3 as
              # the `result` variable is not always used except if the
              # terminator code refers to it.
              result = result = #{@filter}
              halted = (#{chain.config[:terminator]})
              if halted
                halted_callback_hook(#{@raw_filter.inspect.inspect})
              end
            end
            #{code}
          RUBY_EVAL
        when :after
          <<-RUBY_EVAL
          #{code}
          if #{!chain.config[:skip_after_callbacks_if_terminated] || "!halted"} && #{@compiled_options}
            #{@filter}
          end
          RUBY_EVAL
        when :around
          name = define_conditional_callback
          <<-RUBY_EVAL
          #{name}(halted) do
            #{code}
            value
          end
          RUBY_EVAL
        end
      end

      private

      # Compile around filters with conditions into proxy methods
      # that contain the conditions.
      #
      # For `set_callback :save, :around, :filter_name, if: :condition':
      #
      #   def _conditional_callback_save_17
      #     if condition
      #       filter_name do
      #         yield self
      #       end
      #     else
      #       yield self
      #     end
      #   end
      def define_conditional_callback
        name = "_conditional_callback_#{@kind}_#{next_id}"
        @klass.class_eval <<-RUBY_EVAL,  __FILE__, __LINE__ + 1
          def #{name}(halted)
           if #{@compiled_options} && !halted
             #{@filter} do
               yield self
             end
           else
             yield self
           end
         end
        RUBY_EVAL
        name
      end

      # Options support the same options as filters themselves (and support
      # symbols, string, procs, and objects), so compile a conditional
      # expression based on the options.
      def recompile_options!
        conditions = ["true"]

        unless options[:if].empty?
          conditions << Array(_compile_filter(options[:if]))
        end

        unless options[:unless].empty?
          conditions << Array(_compile_filter(options[:unless])).map {|f| "!#{f}"}
        end

        @compiled_options = conditions.flatten.join(" && ")
      end

      # Filters support:
      #
      #   Arrays::  Used in conditions. This is used to specify
      #             multiple conditions. Used internally to
      #             merge conditions from skip_* filters.
      #   Symbols:: A method to call.
      #   Strings:: Some content to evaluate.
      #   Procs::   A proc to call with the object.
      #   Objects:: An object with a <tt>before_foo</tt> method on it to call.
      #
      # All of these objects are compiled into methods and handled
      # the same after this point:
      #
      #   Arrays::  Merged together into a single filter.
      #   Symbols:: Already methods.
      #   Strings:: class_eval'ed into methods.
      #   Procs::   define_method'ed into methods.
      #   Objects::
      #     a method is created that calls the before_foo method
      #     on the object.
      def _compile_filter(filter)
        method_name = "_callback_#{@kind}_#{next_id}"
        case filter
        when Array
          filter.map {|f| _compile_filter(f)}
        when Symbol
          filter
        when String
          "(#{filter})"
        when Proc
          @klass.send(:define_method, method_name, &filter)
          return method_name if filter.arity <= 0

          method_name << (filter.arity == 1 ? "(self)" : " self, Proc.new ")
        else
          @klass.send(:define_method, "#{method_name}_object") { filter }

          _normalize_legacy_filter(kind, filter)
          scopes = Array(chain.config[:scope])
          method_to_call = scopes.map{ |s| s.is_a?(Symbol) ? send(s) : s }.join("_")

          @klass.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{method_name}(&blk)
              #{method_name}_object.send(:#{method_to_call}, self, &blk)
            end
          RUBY_EVAL

          method_name
        end
      end

      def _normalize_legacy_filter(kind, filter)
        if !filter.respond_to?(kind) && filter.respond_to?(:filter)
          message = "Filter object with #filter method is deprecated. Define method corresponding " \
                    "to filter type (#before, #after or #around)."
          ActiveSupport::Deprecation.warn message
          filter.singleton_class.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{kind}(context, &block) filter(context, &block) end
          RUBY_EVAL
        elsif filter.respond_to?(:before) && filter.respond_to?(:after) && kind == :around && !filter.respond_to?(:around)
          message = "Filter object with #before and #after methods is deprecated. Define #around method instead."
          ActiveSupport::Deprecation.warn message
          def filter.around(context)
            should_continue = before(context)
            yield if should_continue
            after(context)
          end
        end
      end
    end

    # An Array with a compile method.
    class CallbackChain < Array #:nodoc:#
      attr_reader :name, :config

      def initialize(name, config)
        @name = name
        @config = {
          :terminator => "false",
          :scope => [ :kind ]
        }.merge(config)
      end

      def compile
        method = []
        method << "value = nil"
        method << "halted = false"

        callbacks = "value = !halted && (!block_given? || yield)"
        reverse_each do |callback|
          callbacks = callback.apply(callbacks)
        end
        method << callbacks

        method << "value"
        method.join("\n")
      end

      def append(*callbacks)
        callbacks.each { |c| append_one(c) }
      end

      def prepend(*callbacks)
        callbacks.each { |c| prepend_one(c) }
      end

      private

      def append_one(callback)
        remove_duplicates(callback)
        push(callback)
      end

      def prepend_one(callback)
        remove_duplicates(callback)
        unshift(callback)
      end

      def remove_duplicates(callback)
        delete_if { |c| callback.duplicates?(c) }
      end

    end

    module ClassMethods

      # This method defines callback chain method for the given kind
      # if it was not yet defined.
      # This generated method plays caching role.
      def __define_callbacks(kind, object) #:nodoc:
        name = __callback_runner_name(kind)
        unless object.respond_to?(name, true)
          str = object.send("_#{kind}_callbacks").compile
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{name}() #{str} end
            protected :#{name}
          RUBY_EVAL
        end
        name
      end

      def __reset_runner(symbol)
        name = __callback_runner_name(symbol)
        undef_method(name) if method_defined?(name)
      end

      def __callback_runner_name_cache
        @__callback_runner_name_cache ||= ThreadSafe::Cache.new {|cache, kind| cache[kind] = __generate_callback_runner_name(kind) }
      end

      def __generate_callback_runner_name(kind)
        "_run__#{self.name.hash.abs}__#{kind}__callbacks"
      end

      def __callback_runner_name(kind)
        __callback_runner_name_cache[kind]
      end

      # This is used internally to append, prepend and skip callbacks to the
      # CallbackChain.
      def __update_callbacks(name, filters = [], block = nil) #:nodoc:
        type = [:before, :after, :around].include?(filters.first) ? filters.shift : :before
        options = filters.last.is_a?(Hash) ? filters.pop : {}
        filters.unshift(block) if block

        ([self] + ActiveSupport::DescendantsTracker.descendants(self)).reverse.each do |target|
          chain = target.send("_#{name}_callbacks")
          yield target, chain.dup, type, filters, options
          target.__reset_runner(name)
        end
      end

      # Install a callback for the given event.
      #
      #   set_callback :save, :before, :before_meth
      #   set_callback :save, :after,  :after_meth, if: :condition
      #   set_callback :save, :around, ->(r, &block) { stuff; result = block.call; stuff }
      #
      # The second arguments indicates whether the callback is to be run +:before+,
      # +:after+, or +:around+ the event. If omitted, +:before+ is assumed. This
      # means the first example above can also be written as:
      #
      #   set_callback :save, :before_meth
      #
      # The callback can specified as a symbol naming an instance method; as a
      # proc, lambda, or block; as a string to be instance evaluated; or as an
      # object that responds to a certain method determined by the <tt>:scope</tt>
      # argument to +define_callback+.
      #
      # If a proc, lambda, or block is given, its body is evaluated in the context
      # of the current object. It can also optionally accept the current object as
      # an argument.
      #
      # Before and around callbacks are called in the order that they are set;
      # after callbacks are called in the reverse order.
      #
      # Around callbacks can access the return value from the event, if it
      # wasn't halted, from the +yield+ call.
      #
      # ===== Options
      #
      # * <tt>:if</tt> - A symbol naming an instance method or a proc; the
      #   callback will be called only when it returns a +true+ value.
      # * <tt>:unless</tt> - A symbol naming an instance method or a proc; the
      #   callback will be called only when it returns a +false+ value.
      # * <tt>:prepend</tt> - If +true+, the callback will be prepended to the
      #   existing chain rather than appended.
      def set_callback(name, *filter_list, &block)
        mapped = nil

        __update_callbacks(name, filter_list, block) do |target, chain, type, filters, options|
          mapped ||= filters.map do |filter|
            Callback.new(chain, filter, type, options.dup, self)
          end

          options[:prepend] ? chain.prepend(*mapped) : chain.append(*mapped)

          target.send("_#{name}_callbacks=", chain)
        end
      end

      # Skip a previously set callback. Like +set_callback+, <tt>:if</tt> or
      # <tt>:unless</tt> options may be passed in order to control when the
      # callback is skipped.
      #
      #   class Writer < Person
      #      skip_callback :validate, :before, :check_membership, if: -> { self.age > 18 }
      #   end
      def skip_callback(name, *filter_list, &block)
        __update_callbacks(name, filter_list, block) do |target, chain, type, filters, options|
          filters.each do |filter|
            filter = chain.find {|c| c.matches?(type, filter) }

            if filter && options.any?
              new_filter = filter.clone(chain, self)
              chain.insert(chain.index(filter), new_filter)
              new_filter.recompile!(options)
            end

            chain.delete(filter)
          end
          target.send("_#{name}_callbacks=", chain)
        end
      end

      # Remove all set callbacks for the given event.
      def reset_callbacks(symbol)
        callbacks = send("_#{symbol}_callbacks")

        ActiveSupport::DescendantsTracker.descendants(self).each do |target|
          chain = target.send("_#{symbol}_callbacks").dup
          callbacks.each { |c| chain.delete(c) }
          target.send("_#{symbol}_callbacks=", chain)
          target.__reset_runner(symbol)
        end

        self.send("_#{symbol}_callbacks=", callbacks.dup.clear)

        __reset_runner(symbol)
      end

      # Define sets of events in the object lifecycle that support callbacks.
      #
      #   define_callbacks :validate
      #   define_callbacks :initialize, :save, :destroy
      #
      # ===== Options
      #
      # * <tt>:terminator</tt> - Determines when a before filter will halt the
      #   callback chain, preventing following callbacks from being called and
      #   the event from being triggered. This is a string to be eval'ed. The
      #   result of the callback is available in the +result+ variable.
      #
      #     define_callbacks :validate, terminator: 'result == false'
      #
      #   In this example, if any before validate callbacks returns +false+,
      #   other callbacks are not executed. Defaults to +false+, meaning no value
      #   halts the chain.
      #
      # * <tt>:skip_after_callbacks_if_terminated</tt> - Determines if after
      #   callbacks should be terminated by the <tt>:terminator</tt> option. By
      #   default after callbacks executed no matter if callback chain was
      #   terminated or not. Option makes sense only when <tt>:terminator</tt>
      #   option is specified.
      #
      # * <tt>:scope</tt> - Indicates which methods should be executed when an
      #   object is used as a callback.
      #
      #     class Audit
      #       def before(caller)
      #         puts 'Audit: before is called'
      #       end
      #
      #       def before_save(caller)
      #         puts 'Audit: before_save is called'
      #       end
      #     end
      #
      #     class Account
      #       include ActiveSupport::Callbacks
      #
      #       define_callbacks :save
      #       set_callback :save, :before, Audit.new
      #
      #       def save
      #         run_callbacks :save do
      #           puts 'save in main'
      #         end
      #       end
      #     end
      #
      #   In the above case whenever you save an account the method
      #   <tt>Audit#before</tt> will be called. On the other hand
      #
      #     define_callbacks :save, scope: [:kind, :name]
      #
      #   would trigger <tt>Audit#before_save</tt> instead. That's constructed
      #   by calling <tt>#{kind}_#{name}</tt> on the given instance. In this
      #   case "kind" is "before" and "name" is "save". In this context +:kind+
      #   and +:name+ have special meanings: +:kind+ refers to the kind of
      #   callback (before/after/around) and +:name+ refers to the method on
      #   which callbacks are being defined.
      #
      #   A declaration like
      #
      #     define_callbacks :save, scope: [:name]
      #
      #   would call <tt>Audit#save</tt>.
      def define_callbacks(*callbacks)
        config = callbacks.last.is_a?(Hash) ? callbacks.pop : {}
        callbacks.each do |callback|
          class_attribute "_#{callback}_callbacks"
          send("_#{callback}_callbacks=", CallbackChain.new(callback, config))
        end
      end
    end
  end
end
