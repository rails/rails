require 'active_support/descendants_tracker'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/class/inheritable_attributes'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/kernel/singleton_class'

module ActiveSupport
  # Callbacks are hooks into the life cycle of an object that allow you to trigger logic
  # before or after an alteration of the object state.
  #
  # Mixing in this module allows you to define callbacks in your class.
  #
  # Example:
  #   class Storage
  #     include ActiveSupport::Callbacks
  #
  #     define_callbacks :save
  #   end
  #
  #   class ConfigStorage < Storage
  #     set_callback :save, :before, :saving_message
  #     def saving_message
  #       puts "saving..."
  #     end
  #
  #     set_callback :save, :after do |object|
  #       puts "saved"
  #     end
  #
  #     def save
  #       run_callbacks :save do
  #         puts "- save"
  #       end
  #     end
  #   end
  #
  #   config = ConfigStorage.new
  #   config.save
  #
  # Output:
  #   saving...
  #   - save
  #   saved
  #
  # Callbacks from parent classes are inherited.
  #
  # Example:
  #   class Storage
  #     include ActiveSupport::Callbacks
  #
  #     define_callbacks :save
  #
  #     set_callback :save, :before, :prepare
  #     def prepare
  #       puts "preparing save"
  #     end
  #   end
  #
  #   class ConfigStorage < Storage
  #     set_callback :save, :before, :saving_message
  #     def saving_message
  #       puts "saving..."
  #     end
  #
  #     set_callback :save, :after do |object|
  #       puts "saved"
  #     end
  #
  #     def save
  #       run_callbacks :save do
  #         puts "- save"
  #       end
  #     end
  #   end
  #
  #   config = ConfigStorage.new
  #   config.save
  #
  # Output:
  #   preparing save
  #   saving...
  #   - save
  #   saved
  #
  module Callbacks
    extend Concern

    included do
      extend ActiveSupport::DescendantsTracker
    end

    def run_callbacks(kind, *args, &block)
      send("_run_#{kind}_callbacks", *args, &block)
    end

    def callback(kind)
      ActiveSupport::Deprecation.warn("callback is deprecated. Please use run_callbacks")
      send("_run_#{kind}_callbacks")
    end

    class Callback
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
        if @kind == :before || @kind == :around
          if @kind == :before
            # if condition    # before_save :filter_name, :if => :condition
            #   filter_name
            # end
            filter = <<-RUBY_EVAL
              unless halted
                result = #{@filter}
                halted = (#{chain.config[:terminator]})
              end
            RUBY_EVAL

            [@compiled_options[0], filter, @compiled_options[1]].compact.join("\n")
          else
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
      end

      # This will supply contents for around and after filters, but not
      # before filters (for the backward pass).
      def end(key=nil, object=nil)
        return if key && !object.send("_one_time_conditions_valid_#{@callback_id}?")

        if @kind == :around || @kind == :after
          # if condition    # after_save :filter_name, :if => :condition
          #   filter_name
          # end
          if @kind == :after
            [@compiled_options[0], @filter, @compiled_options[1]].compact.join("\n")
          else
            "end"
          end
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
    class CallbackChain < Array
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
      # Make the run_callbacks :save method. The generated method takes
      # a block that it'll yield to. It'll call the before and around filters
      # in order, yield the block, and then run the after filters.
      #
      # run_callbacks :save do
      #   save
      # end
      #
      # The run_callbacks :save method can optionally take a key, which
      # will be used to compile an optimized callback method for each
      # key. See #define_callbacks for more information.
      #
      def __define_runner(symbol) #:nodoc:
        body = send("_#{symbol}_callbacks").compile(nil)

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
        type = [:before, :after, :around].include?(filters.first) ? filters.shift : :before
        options = filters.last.is_a?(Hash) ? filters.pop : {}
        filters.unshift(block) if block

        ([self] + ActiveSupport::DescendantsTracker.descendants(self)).each do |target|
          chain = target.send("_#{name}_callbacks")
          yield chain, type, filters, options
          target.__define_runner(name)
        end
      end

      # Set callbacks for a previously defined callback.
      #
      # Syntax:
      #   set_callback :save, :before, :before_meth
      #   set_callback :save, :after,  :after_meth, :if => :condition
      #   set_callback :save, :around, lambda { |r| stuff; yield; stuff }
      #
      # Use skip_callback to skip any defined one.
      #
      # When creating or skipping callbacks, you can specify conditions that
      # are always the same for a given key. For instance, in Action Pack,
      # we convert :only and :except conditions into per-key conditions.
      #
      #   before_filter :authenticate, :except => "index"
      #
      # becomes
      #
      #   dispatch_callback :before, :authenticate, :per_key => {:unless => proc {|c| c.action_name == "index"}}
      #
      # Per-Key conditions are evaluated only once per use of a given key.
      # In the case of the above example, you would do:
      #
      #   run_callbacks(:dispatch, action_name) { ... dispatch stuff ... }
      #
      # In that case, each action_name would get its own compiled callback
      # method that took into consideration the per_key conditions. This
      # is a speed improvement for ActionPack.
      #
      def set_callback(name, *filter_list, &block)
        mapped = nil

        __update_callbacks(name, filter_list, block) do |chain, type, filters, options|
          mapped ||= filters.map do |filter|
            Callback.new(chain, filter, type, options.dup, self)
          end

          filters.each do |filter|
            chain.delete_if {|c| c.matches?(type, filter) }
          end

          options[:prepend] ? chain.unshift(*(mapped.reverse)) : chain.push(*mapped)
        end
      end

      # Skip a previously defined callback for a given type.
      #
      def skip_callback(name, *filter_list, &block)
        __update_callbacks(name, filter_list, block) do |chain, type, filters, options|
          filters.each do |filter|
            filter = chain.find {|c| c.matches?(type, filter) }

            if filter && options.any?
              new_filter = filter.clone(chain, self)
              chain.insert(chain.index(filter), new_filter)
              new_filter.recompile!(options, options[:per_key] || {})
            end

            chain.delete(filter)
          end
        end
      end

      # Reset callbacks for a given type.
      #
      def reset_callbacks(symbol)
        callbacks = send("_#{symbol}_callbacks")

        ActiveSupport::DescendantsTracker.descendants(self).each do |target|
          chain = target.send("_#{symbol}_callbacks")
          callbacks.each { |c| chain.delete(c) }
          target.__define_runner(symbol)
        end

        callbacks.clear
        __define_runner(symbol)
      end

      # Defines callbacks types:
      #
      #   define_callbacks :validate
      #
      # This macro accepts the following options:
      #
      # * <tt>:terminator</tt> - Indicates when a before filter is considered
      # to be halted.
      #
      #   define_callbacks :validate, :terminator => "result == false"
      #
      # In the example above, if any before validate callbacks returns +false+,
      # other callbacks are not executed. Defaults to "false", meaning no value
      # halts the chain.
      #
      # * <tt>:rescuable</tt> - By default, after filters are not executed if
      # the given block or a before filter raises an error. Set this option to
      # true to change this behavior.
      #
      # * <tt>:scope</tt> - Indicates which methods should be executed when a class
      # is given as callback. Defaults to <tt>[:kind]</tt>.
      #
      #  class Audit
      #    def before(caller)
      #      puts 'Audit: before is called'
      #    end
      #
      #    def before_save(caller)
      #      puts 'Audit: before_save is called'
      #    end
      #  end
      #
      #  class Account
      #    include ActiveSupport::Callbacks
      #
      #    define_callbacks :save
      #    set_callback :save, :before, Audit.new
      #
      #    def save
      #      run_callbacks :save do
      #        puts 'save in main'
      #      end
      #    end
      #  end
      #
      # In the above case whenever you save an account the method <tt>Audit#before</tt> will
      # be called. On the other hand
      #
      #   define_callbacks :save, :scope => [:kind, :name]
      #
      # would trigger <tt>Audit#before_save</tt> instead. That's constructed by calling
      # <tt>"#{kind}_#{name}"</tt> on the given instance. In this case "kind" is "before" and
      # "name" is "save". In this context ":kind" and ":name" have special meanings: ":kind"
      # refers to the kind of callback (before/after/around) and ":name" refers to the
      # method on which callbacks are being defined.
      #
      # A declaration like
      #
      #   define_callbacks :save, :scope => [:name]
      #
      # would call <tt>Audit#save</tt>.
      #
      def define_callbacks(*callbacks)
        config = callbacks.last.is_a?(Hash) ? callbacks.pop : {}
        callbacks.each do |callback|
          extlib_inheritable_reader("_#{callback}_callbacks") do
            CallbackChain.new(callback, config)
          end
          __define_runner(callback)
        end
      end
    end
  end
end
