require 'active_support/concern'
require 'active_support/descendants_tracker'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/object/inclusion'

module ActiveSupport
  # \Callbacks are code hooks that are run at key points in an object's lifecycle.
  # The typical use case is to have a base class define a set of callbacks relevant
  # to the other functionality it supplies, so that subclasses can install callbacks
  # that enhance or modify the base functionality without needing to override
  # or redefine methods of the base class.
  #
  # Mixing in this module allows you to define the events in the object's lifecycle
  # that will support callbacks (via +ClassMethods.define_callbacks+), set the instance
  # methods, procs, or callback objects to be called (via +ClassMethods.set_callback+),
  # and run the installed callbacks at the appropriate times (via +run_callbacks+).
  #
  # Three kinds of callbacks are supported: before callbacks, run before a certain event;
  # after callbacks, run after the event; and around callbacks, blocks that surround the
  # event, triggering it when they yield. Callback code can be contained in instance
  # methods, procs or lambdas, or callback objects that respond to certain predetermined
  # methods. See +ClassMethods.set_callback+ for details.
  #
  # ==== Example
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
  #
  module Callbacks
    extend Concern

    included do
      extend ActiveSupport::DescendantsTracker
    end

    # Runs the callbacks for the given event.
    #
    # Calls the before and around callbacks in the order they were set, yields
    # the block (if given one), and then runs the after callbacks in reverse order.
    # Optionally accepts a key, which will be used to compile an optimized callback
    # method for each key. See +ClassMethods.define_callbacks+ for more information.
    #
    # If the callback chain was halted, returns +false+. Otherwise returns the result
    # of the block, or +true+ if no block is given.
    #
    #   run_callbacks :save do
    #     save
    #   end
    #
    def run_callbacks(kind, *args, &block)
      send("_run_#{kind}_callbacks", *args, &block)
    end

    class Callback #:nodoc:#
      @@_callback_sequence = 0

      attr_accessor :chain, :filter, :kind, :options, :per_key, :klass, :raw_filter

      def initialize(chain, filter, kind, options, klass)
        @chain, @kind, @klass = chain, kind, klass
        normalize_options!(options)

        @per_key              = options.delete(:per_key)
        @raw_filter, @options = filter, options
        @filter               = _compile_filter(filter)
        @compiled_options     = _compile_options(options)
        @callback_id          = next_id

        _compile_per_key_options
      end

      def clone(chain, klass)
        obj                  = super()
        obj.chain            = chain
        obj.klass            = klass
        obj.per_key          = @per_key.dup
        obj.options          = @options.dup
        obj.per_key[:if]     = @per_key[:if].dup
        obj.per_key[:unless] = @per_key[:unless].dup
        obj.options[:if]     = @options[:if].dup
        obj.options[:unless] = @options[:unless].dup
        obj
      end

      def normalize_options!(options)
        options[:if] = Array.wrap(options[:if])
        options[:unless] = Array.wrap(options[:unless])

        options[:per_key] ||= {}
        options[:per_key][:if] = Array.wrap(options[:per_key][:if])
        options[:per_key][:unless] = Array.wrap(options[:per_key][:unless])
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

      def _update_filter(filter_options, new_options)
        filter_options[:if].push(new_options[:unless]) if new_options.key?(:unless)
        filter_options[:unless].push(new_options[:if]) if new_options.key?(:if)
      end

      def recompile!(_options, _per_key)
        _update_filter(self.options, _options)
        _update_filter(self.per_key, _per_key)

        @callback_id      = next_id
        @filter           = _compile_filter(@raw_filter)
        @compiled_options = _compile_options(@options)
                            _compile_per_key_options
      end

      def _compile_per_key_options
        key_options  = _compile_options(@per_key)

        @klass.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def _one_time_conditions_valid_#{@callback_id}?
            true #{key_options[0]}
          end
        RUBY_EVAL
      end

      # This will supply contents for before and around filters, and no
      # contents for after filters (for the forward pass).
      def start(key=nil, object=nil)
        return if key && !object.send("_one_time_conditions_valid_#{@callback_id}?")

        # options[0] is the compiled form of supplied conditions
        # options[1] is the "end" for the conditional
        #
        case @kind
        when :before
          # if condition    # before_save :filter_name, :if => :condition
          #   filter_name
          # end
          filter = <<-RUBY_EVAL
            unless halted
              # This double assignment is to prevent warnings in 1.9.3.  I would
              # remove the `result` variable, but apparently some other
              # generated code is depending on this variable being set sometimes
              # and sometimes not.
              result = result = #{@filter}
              halted = (#{chain.config[:terminator]})
            end
          RUBY_EVAL

          [@compiled_options[0], filter, @compiled_options[1]].compact.join("\n")
        when :around
          # Compile around filters with conditions into proxy methods
          # that contain the conditions.
          #
          # For `around_save :filter_name, :if => :condition':
          #
          # def _conditional_callback_save_17
          #   if condition
          #     filter_name do
          #       yield self
          #     end
          #   else
          #     yield self
          #   end
          # end
          #
          name = "_conditional_callback_#{@kind}_#{next_id}"
          @klass.class_eval <<-RUBY_EVAL,  __FILE__, __LINE__ + 1
             def #{name}(halted)
              #{@compiled_options[0] || "if true"} && !halted
                #{@filter} do
                  yield self
                end
              else
                yield self
              end
            end
          RUBY_EVAL
          "#{name}(halted) do"
        end
      end

      # This will supply contents for around and after filters, but not
      # before filters (for the backward pass).
      def end(key=nil, object=nil)
        return if key && !object.send("_one_time_conditions_valid_#{@callback_id}?")

        case @kind
        when :after
          # if condition    # after_save :filter_name, :if => :condition
          #   filter_name
          # end
          [@compiled_options[0], @filter, @compiled_options[1]].compact.join("\n")
        when :around
          <<-RUBY_EVAL
            value
          end
          RUBY_EVAL
        end
      end

      private

      # Options support the same options as filters themselves (and support
      # symbols, string, procs, and objects), so compile a conditional
      # expression based on the options
      def _compile_options(options)
        return [] if options[:if].empty? && options[:unless].empty?

        conditions = []

        unless options[:if].empty?
          conditions << Array.wrap(_compile_filter(options[:if]))
        end

        unless options[:unless].empty?
          conditions << Array.wrap(_compile_filter(options[:unless])).map {|f| "!#{f}"}
        end

        ["if #{conditions.flatten.join(" && ")}", "end"]
      end

      # Filters support:
      #
      #   Arrays::  Used in conditions. This is used to specify
      #             multiple conditions. Used internally to
      #             merge conditions from skip_* filters
      #   Symbols:: A method to call
      #   Strings:: Some content to evaluate
      #   Procs::   A proc to call with the object
      #   Objects:: An object with a before_foo method on it to call
      #
      # All of these objects are compiled into methods and handled
      # the same after this point:
      #
      #   Arrays::  Merged together into a single filter
      #   Symbols:: Already methods
      #   Strings:: class_eval'ed into methods
      #   Procs::   define_method'ed into methods
      #   Objects::
      #     a method is created that calls the before_foo method
      #     on the object.
      #
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
          scopes = Array.wrap(chain.config[:scope])
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
          filter.singleton_class.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{kind}(context, &block) filter(context, &block) end
          RUBY_EVAL
        elsif filter.respond_to?(:before) && filter.respond_to?(:after) && kind == :around
          def filter.around(context)
            should_continue = before(context)
            yield if should_continue
            after(context)
          end
        end
      end
    end

    # An Array with a compile method
    class CallbackChain < Array #:nodoc:#
      attr_reader :name, :config

      def initialize(name, config)
        @name = name
        @config = {
          :terminator => "false",
          :rescuable => false,
          :scope => [ :kind ]
        }.merge(config)
      end

      def compile(key=nil, object=nil)
        method = []
        method << "value = nil"
        method << "halted = false"

        each do |callback|
          method << callback.start(key, object)
        end

        if config[:rescuable]
          method << "rescued_error = nil"
          method << "begin"
        end

        method << "value = yield if block_given? && !halted"

        if config[:rescuable]
          method << "rescue Exception => e"
          method << "rescued_error = e"
          method << "end"
        end

        reverse_each do |callback|
          method << callback.end(key, object)
        end

        method << "raise rescued_error if rescued_error" if config[:rescuable]
        method << "halted ? false : (block_given? ? value : true)"
        method.compact.join("\n")
      end
    end

    module ClassMethods
      # Generate the internal runner method called by +run_callbacks+.
      def __define_runner(symbol) #:nodoc:
        body = send("_#{symbol}_callbacks").compile

        silence_warnings do
          undef_method "_run_#{symbol}_callbacks" if method_defined?("_run_#{symbol}_callbacks")
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def _run_#{symbol}_callbacks(key = nil, &blk)
              if key
                name = "_run__\#{self.class.name.hash.abs}__#{symbol}__\#{key.hash.abs}__callbacks"

                unless respond_to?(name)
                  self.class.__create_keyed_callback(name, :#{symbol}, self, &blk)
                end

                send(name, &blk)
              else
                #{body}
              end
            end
            private :_run_#{symbol}_callbacks
          RUBY_EVAL
        end
      end

      # This is called the first time a callback is called with a particular
      # key. It creates a new callback method for the key, calculating
      # which callbacks can be omitted because of per_key conditions.
      #
      def __create_keyed_callback(name, kind, object, &blk) #:nodoc:
        @_keyed_callbacks ||= {}
        @_keyed_callbacks[name] ||= begin
          str = send("_#{kind}_callbacks").compile(name, object)
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def #{name}() #{str} end
            protected :#{name}
          RUBY_EVAL
          true
        end
      end

      # This is used internally to append, prepend and skip callbacks to the
      # CallbackChain.
      #
      def __update_callbacks(name, filters = [], block = nil) #:nodoc:
        type = filters.first.in?([:before, :after, :around]) ? filters.shift : :before
        options = filters.last.is_a?(Hash) ? filters.pop : {}
        filters.unshift(block) if block

        ([self] + ActiveSupport::DescendantsTracker.descendants(self)).reverse.each do |target|
          chain = target.send("_#{name}_callbacks")
          yield target, chain.dup, type, filters, options
          target.__define_runner(name)
        end
      end

      # Install a callback for the given event.
      #
      #   set_callback :save, :before, :before_meth
      #   set_callback :save, :after,  :after_meth, :if => :condition
      #   set_callback :save, :around, lambda { |r| stuff; result = yield; stuff }
      #
      # The second arguments indicates whether the callback is to be run +:before+,
      # +:after+, or +:around+ the event. If omitted, +:before+ is assumed. This
      # means the first example above can also be written as:
      #
      #   set_callback :save, :before_meth
      #
      # The callback can specified as a symbol naming an instance method; as a proc,
      # lambda, or block; as a string to be instance evaluated; or as an object that
      # responds to a certain method determined by the <tt>:scope</tt> argument to
      # +define_callback+.
      #
      # If a proc, lambda, or block is given, its body is evaluated in the context
      # of the current object. It can also optionally accept the current object as
      # an argument.
      #
      # Before and around callbacks are called in the order that they are set; after
      # callbacks are called in the reverse order.
      # 
      # Around callbacks can access the return value from the event, if it
      # wasn't halted, from the +yield+ call.
      #
      # ===== Options
      #
      # * <tt>:if</tt> - A symbol naming an instance method or a proc; the callback
      #   will be called only when it returns a true value.
      # * <tt>:unless</tt> - A symbol naming an instance method or a proc; the callback
      #   will be called only when it returns a false value.
      # * <tt>:prepend</tt> - If true, the callback will be prepended to the existing
      #   chain rather than appended.
      # * <tt>:per_key</tt> - A hash with <tt>:if</tt> and <tt>:unless</tt> options;
      #   see "Per-key conditions" below.
      #
      # ===== Per-key conditions
      #
      # When creating or skipping callbacks, you can specify conditions that
      # are always the same for a given key. For instance, in Action Pack,
      # we convert :only and :except conditions into per-key conditions.
      #
      #   before_filter :authenticate, :except => "index"
      #
      # becomes
      #
      #   set_callback :process_action, :before, :authenticate, :per_key => {:unless => proc {|c| c.action_name == "index"}}
      #
      # Per-key conditions are evaluated only once per use of a given key.
      # In the case of the above example, you would do:
      #
      #   run_callbacks(:process_action, action_name) { ... dispatch stuff ... }
      #
      # In that case, each action_name would get its own compiled callback
      # method that took into consideration the per_key conditions. This
      # is a speed improvement for ActionPack.
      #
      def set_callback(name, *filter_list, &block)
        mapped = nil

        __update_callbacks(name, filter_list, block) do |target, chain, type, filters, options|
          mapped ||= filters.map do |filter|
            Callback.new(chain, filter, type, options.dup, self)
          end

          filters.each do |filter|
            chain.delete_if {|c| c.matches?(type, filter) }
          end

          options[:prepend] ? chain.unshift(*(mapped.reverse)) : chain.push(*mapped)

          target.send("_#{name}_callbacks=", chain)
        end
      end

      # Skip a previously set callback. Like +set_callback+, <tt>:if</tt> or <tt>:unless</tt>
      # options may be passed in order to control when the callback is skipped.
      #
      #   class Writer < Person
      #      skip_callback :validate, :before, :check_membership, :if => lambda { self.age > 18 }
      #   end
      #
      def skip_callback(name, *filter_list, &block)
        __update_callbacks(name, filter_list, block) do |target, chain, type, filters, options|
          filters.each do |filter|
            filter = chain.find {|c| c.matches?(type, filter) }

            if filter && options.any?
              new_filter = filter.clone(chain, self)
              chain.insert(chain.index(filter), new_filter)
              new_filter.recompile!(options, options[:per_key] || {})
            end

            chain.delete(filter)
          end
          target.send("_#{name}_callbacks=", chain)
        end
      end

      # Remove all set callbacks for the given event.
      #
      def reset_callbacks(symbol)
        callbacks = send("_#{symbol}_callbacks")

        ActiveSupport::DescendantsTracker.descendants(self).each do |target|
          chain = target.send("_#{symbol}_callbacks").dup
          callbacks.each { |c| chain.delete(c) }
          target.send("_#{symbol}_callbacks=", chain)
          target.__define_runner(symbol)
        end

        self.send("_#{symbol}_callbacks=", callbacks.dup.clear)

        __define_runner(symbol)
      end

      # Define sets of events in the object lifecycle that support callbacks.
      #
      #   define_callbacks :validate
      #   define_callbacks :initialize, :save, :destroy
      #
      # ===== Options
      #
      # * <tt>:terminator</tt> - Determines when a before filter will halt the callback
      #   chain, preventing following callbacks from being called and the event from being
      #   triggered. This is a string to be eval'ed. The result of the callback is available
      #   in the <tt>result</tt> variable.
      #
      #     define_callbacks :validate, :terminator => "result == false"
      #
      #   In this example, if any before validate callbacks returns +false+,
      #   other callbacks are not executed. Defaults to "false", meaning no value
      #   halts the chain.
      #
      # * <tt>:rescuable</tt> - By default, after filters are not executed if
      #   the given block or a before filter raises an error. By setting this option
      #   to <tt>true</tt> exception raised by given block is stored and after
      #   executing all the after callbacks the stored exception is raised.
      #
      # * <tt>:scope</tt> - Indicates which methods should be executed when an object
      #   is used as a callback.
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
      #   In the above case whenever you save an account the method <tt>Audit#before</tt> will
      #   be called. On the other hand
      #
      #     define_callbacks :save, :scope => [:kind, :name]
      #
      #   would trigger <tt>Audit#before_save</tt> instead. That's constructed by calling
      #   <tt>#{kind}_#{name}</tt> on the given instance. In this case "kind" is "before" and
      #   "name" is "save". In this context +:kind+ and +:name+ have special meanings: +:kind+
      #   refers to the kind of callback (before/after/around) and +:name+ refers to the
      #   method on which callbacks are being defined.
      #
      #   A declaration like
      #
      #     define_callbacks :save, :scope => [:name]
      #
      #   would call <tt>Audit#save</tt>.
      #
      def define_callbacks(*callbacks)
        config = callbacks.last.is_a?(Hash) ? callbacks.pop : {}
        callbacks.each do |callback|
          class_attribute "_#{callback}_callbacks"
          send("_#{callback}_callbacks=", CallbackChain.new(callback, config))
          __define_runner(callback)
        end
      end
    end
  end
end
