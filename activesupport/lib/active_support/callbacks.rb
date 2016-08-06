require "active_support/concern"
require "active_support/descendants_tracker"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/class/attribute"
require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/kernel/singleton_class"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/string/filters"
require "active_support/deprecation"
require "thread"

module ActiveSupport
  # Callbacks are code hooks that are run at key points in an object's life cycle.
  # The typical use case is to have a base class define a set of callbacks
  # relevant to the other functionality it supplies, so that subclasses can
  # install callbacks that enhance or modify the base functionality without
  # needing to override or redefine methods of the base class.
  #
  # Mixing in this module allows you to define the events in the object's
  # life cycle that will support callbacks (via +ClassMethods.define_callbacks+),
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

    CALLBACK_FILTER_TYPES = [:before, :after, :around]

    # If true, Active Record and Active Model callbacks returning +false+ will
    # halt the entire callback chain and display a deprecation message.
    # If false, callback chains will only be halted by calling +throw :abort+.
    # Defaults to +true+.
    mattr_accessor(:halt_and_display_warning_on_return_false, instance_writer: false) { true }

    # Runs the callbacks for the given event.
    #
    # Calls the before and around callbacks in the order they were set, yields
    # the block (if given one), and then runs the after callbacks in reverse
    # order.
    #
    # If the callback chain was halted, returns +false+. Otherwise returns the
    # result of the block, +nil+ if no callbacks have been set, or +true+
    # if callbacks have been set but no block is given.
    #
    #   run_callbacks :save do
    #     save
    #   end
    def run_callbacks(kind, &block)
      send "_run_#{kind}_callbacks", &block
    end

    private

      def __run_callbacks__(callbacks, &block)
        if callbacks.empty?
          yield if block_given?
        else
          runner = callbacks.compile
          e = Filters::Environment.new(self, false, nil, block)
          runner.call(e).value
        end
      end

    # A hook invoked every time a before callback is halted.
    # This can be overridden in ActiveSupport::Callbacks implementors in order
    # to provide better debugging/logging.
      def halted_callback_hook(filter)
      end

      module Conditionals # :nodoc:
        class Value
          def initialize(&block)
            @block = block
          end
          def call(target, value); @block.call(value); end
        end
      end

      module Filters
        Environment = Struct.new(:target, :halted, :value, :run_block)

        class End
          def call(env)
            block = env.run_block
            env.value = !env.halted && (!block || block.call)
            env
          end
        end
        ENDING = End.new

        class Before
          def self.build(callback_sequence, user_callback, user_conditions, chain_config, filter)
            halted_lambda = chain_config[:terminator]

            if user_conditions.any?
              halting_and_conditional(callback_sequence, user_callback, user_conditions, halted_lambda, filter)
            else
              halting(callback_sequence, user_callback, halted_lambda, filter)
            end
          end

          def self.halting_and_conditional(callback_sequence, user_callback, user_conditions, halted_lambda, filter)
            callback_sequence.before do |env|
              target = env.target
              value  = env.value
              halted = env.halted

              if !halted && user_conditions.all? { |c| c.call(target, value) }
                result_lambda = -> { user_callback.call target, value }
                env.halted = halted_lambda.call(target, result_lambda)
                if env.halted
                  target.send :halted_callback_hook, filter
                end
              end

              env
            end
          end
          private_class_method :halting_and_conditional

          def self.halting(callback_sequence, user_callback, halted_lambda, filter)
            callback_sequence.before do |env|
              target = env.target
              value  = env.value
              halted = env.halted

              unless halted
                result_lambda = -> { user_callback.call target, value }
                env.halted = halted_lambda.call(target, result_lambda)

                if env.halted
                  target.send :halted_callback_hook, filter
                end
              end

              env
            end
          end
          private_class_method :halting
        end

        class After
          def self.build(callback_sequence, user_callback, user_conditions, chain_config)
            if chain_config[:skip_after_callbacks_if_terminated]
              if user_conditions.any?
                halting_and_conditional(callback_sequence, user_callback, user_conditions)
              else
                halting(callback_sequence, user_callback)
              end
            else
              if user_conditions.any?
                conditional callback_sequence, user_callback, user_conditions
              else
                simple callback_sequence, user_callback
              end
            end
          end

          def self.halting_and_conditional(callback_sequence, user_callback, user_conditions)
            callback_sequence.after do |env|
              target = env.target
              value  = env.value
              halted = env.halted

              if !halted && user_conditions.all? { |c| c.call(target, value) }
                user_callback.call target, value
              end

              env
            end
          end
          private_class_method :halting_and_conditional

          def self.halting(callback_sequence, user_callback)
            callback_sequence.after do |env|
              unless env.halted
                user_callback.call env.target, env.value
              end

              env
            end
          end
          private_class_method :halting

          def self.conditional(callback_sequence, user_callback, user_conditions)
            callback_sequence.after do |env|
              target = env.target
              value  = env.value

              if user_conditions.all? { |c| c.call(target, value) }
                user_callback.call target, value
              end

              env
            end
          end
          private_class_method :conditional

          def self.simple(callback_sequence, user_callback)
            callback_sequence.after do |env|
              user_callback.call env.target, env.value

              env
            end
          end
          private_class_method :simple
        end

        class Around
          def self.build(callback_sequence, user_callback, user_conditions, chain_config)
            if user_conditions.any?
              halting_and_conditional(callback_sequence, user_callback, user_conditions)
            else
              halting(callback_sequence, user_callback)
            end
          end

          def self.halting_and_conditional(callback_sequence, user_callback, user_conditions)
            callback_sequence.around do |env, &run|
              target = env.target
              value  = env.value
              halted = env.halted

              if !halted && user_conditions.all? { |c| c.call(target, value) }
                user_callback.call(target, value) {
                  run.call.value
                }
                env
              else
                run.call
              end
            end
          end
          private_class_method :halting_and_conditional

          def self.halting(callback_sequence, user_callback)
            callback_sequence.around do |env, &run|
              target = env.target
              value  = env.value

              if env.halted
                run.call
              else
                user_callback.call(target, value) {
                  run.call.value
                }
                env
              end
            end
          end
          private_class_method :halting
        end
      end

      class Callback #:nodoc:#
        def self.build(chain, filter, kind, options)
          if filter.is_a?(String)
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Passing string to define callback is deprecated and will be removed
            in Rails 5.1 without replacement.
          MSG
          end

          new chain.name, filter, kind, options, chain.config
        end

        attr_accessor :kind, :name
        attr_reader :chain_config

        def initialize(name, filter, kind, options, chain_config)
          @chain_config  = chain_config
          @name    = name
          @kind    = kind
          @filter  = filter
          @key     = compute_identifier filter
          @if      = Array(options[:if])
          @unless  = Array(options[:unless])
        end

        def filter; @key; end
        def raw_filter; @filter; end

        def merge_conditional_options(chain, if_option:, unless_option:)
          options = {
            if: @if.dup,
            unless: @unless.dup
          }

          options[:if].concat     Array(unless_option)
          options[:unless].concat Array(if_option)

          self.class.build chain, @filter, @kind, options
        end

        def matches?(_kind, _filter)
          @kind == _kind && filter == _filter
        end

        def duplicates?(other)
          case @filter
          when Symbol, String
            matches?(other.kind, other.filter)
          else
            false
          end
        end

        # Wraps code with filter
        def apply(callback_sequence)
          user_conditions = conditions_lambdas
          user_callback = make_lambda @filter

          case kind
          when :before
            Filters::Before.build(callback_sequence, user_callback, user_conditions, chain_config, @filter)
          when :after
            Filters::After.build(callback_sequence, user_callback, user_conditions, chain_config)
          when :around
            Filters::Around.build(callback_sequence, user_callback, user_conditions, chain_config)
          end
        end

        private

          def invert_lambda(l)
            lambda { |*args, &blk| !l.call(*args, &blk) }
          end

        # Filters support:
        #
        #   Symbols:: A method to call.
        #   Strings:: Some content to evaluate.
        #   Procs::   A proc to call with the object.
        #   Objects:: An object with a <tt>before_foo</tt> method on it to call.
        #
        # All of these objects are converted into a lambda and handled
        # the same after this point.
          def make_lambda(filter)
            case filter
            when Symbol
              lambda { |target, _, &blk| target.send filter, &blk }
            when String
              l = eval "lambda { |value| #{filter} }"
              lambda { |target, value| target.instance_exec(value, &l) }
            when Conditionals::Value then filter
            when ::Proc
              if filter.arity > 1
                return lambda { |target, _, &block|
                  raise ArgumentError unless block
                  target.instance_exec(target, block, &filter)
                }
              end

              if filter.arity <= 0
                lambda { |target, _| target.instance_exec(&filter) }
              else
                lambda { |target, _| target.instance_exec(target, &filter) }
              end
            else
              scopes = Array(chain_config[:scope])
              method_to_call = scopes.map{ |s| public_send(s) }.join("_")

              lambda { |target, _, &blk|
                filter.public_send method_to_call, target, &blk
              }
            end
          end

          def compute_identifier(filter)
            case filter
            when String, ::Proc
              filter.object_id
            else
              filter
            end
          end

          def conditions_lambdas
            @if.map { |c| make_lambda c } +
              @unless.map { |c| invert_lambda make_lambda c }
          end
      end

    # Execute before and after filters in a sequence instead of
    # chaining them with nested lambda calls, see:
    # https://github.com/rails/rails/issues/18011
      class CallbackSequence
        def initialize(&call)
          @call = call
          @before = []
          @after = []
        end

        def before(&before)
          @before.unshift(before)
          self
        end

        def after(&after)
          @after.push(after)
          self
        end

        def around(&around)
          CallbackSequence.new do |arg|
            around.call(arg) {
              self.call(arg)
            }
          end
        end

        def call(arg)
          @before.each { |b| b.call(arg) }
          value = @call.call(arg)
          @after.each { |a| a.call(arg) }
          value
        end
      end

    # An Array with a compile method.
      class CallbackChain #:nodoc:#
        include Enumerable

        attr_reader :name, :config

        def initialize(name, config)
          @name = name
          @config = {
            scope: [:kind],
            terminator: default_terminator
          }.merge!(config)
          @chain = []
          @callbacks = nil
          @mutex = Mutex.new
        end

        def each(&block); @chain.each(&block); end
        def index(o);     @chain.index(o); end
        def empty?;       @chain.empty?; end

        def insert(index, o)
          @callbacks = nil
          @chain.insert(index, o)
        end

        def delete(o)
          @callbacks = nil
          @chain.delete(o)
        end

        def clear
          @callbacks = nil
          @chain.clear
          self
        end

        def initialize_copy(other)
          @callbacks = nil
          @chain     = other.chain.dup
          @mutex     = Mutex.new
        end

        def compile
          @callbacks || @mutex.synchronize do
            final_sequence = CallbackSequence.new { |env| Filters::ENDING.call(env) }
            @callbacks ||= @chain.reverse.inject(final_sequence) do |callback_sequence, callback|
              callback.apply callback_sequence
            end
          end
        end

        def append(*callbacks)
          callbacks.each { |c| append_one(c) }
        end

        def prepend(*callbacks)
          callbacks.each { |c| prepend_one(c) }
        end

        protected
          def chain; @chain; end

        private

          def append_one(callback)
            @callbacks = nil
            remove_duplicates(callback)
            @chain.push(callback)
          end

          def prepend_one(callback)
            @callbacks = nil
            remove_duplicates(callback)
            @chain.unshift(callback)
          end

          def remove_duplicates(callback)
            @callbacks = nil
            @chain.delete_if { |c| callback.duplicates?(c) }
          end

          def default_terminator
            Proc.new do |target, result_lambda|
              terminate = true
              catch(:abort) do
                result_lambda.call if result_lambda.is_a?(Proc)
                terminate = false
              end
              terminate
            end
          end
      end

      module ClassMethods
        def normalize_callback_params(filters, block) # :nodoc:
          type = CALLBACK_FILTER_TYPES.include?(filters.first) ? filters.shift : :before
          options = filters.extract_options!
          filters.unshift(block) if block
          [type, filters, options.dup]
        end

        # This is used internally to append, prepend and skip callbacks to the
        # CallbackChain.
        def __update_callbacks(name) #:nodoc:
          ([self] + ActiveSupport::DescendantsTracker.descendants(self)).reverse_each do |target|
            chain = target.get_callbacks name
            yield target, chain.dup
          end
        end

        # Install a callback for the given event.
        #
        #   set_callback :save, :before, :before_method
        #   set_callback :save, :after,  :after_method, if: :condition
        #   set_callback :save, :around, ->(r, block) { stuff; result = block.call; stuff }
        #
        # The second argument indicates whether the callback is to be run +:before+,
        # +:after+, or +:around+ the event. If omitted, +:before+ is assumed. This
        # means the first example above can also be written as:
        #
        #   set_callback :save, :before_method
        #
        # The callback can be specified as a symbol naming an instance method; as a
        # proc, lambda, or block; as a string to be instance evaluated(deprecated); or as an
        # object that responds to a certain method determined by the <tt>:scope</tt>
        # argument to +define_callbacks+.
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
        # * <tt>:if</tt> - A symbol, a string or an array of symbols and strings,
        #   each naming an instance method or a proc; the callback will be called
        #   only when they all return a true value.
        # * <tt>:unless</tt> - A symbol, a string or an array of symbols and
        #   strings, each naming an instance method or a proc; the callback will
        #   be called only when they all return a false value.
        # * <tt>:prepend</tt> - If +true+, the callback will be prepended to the
        #   existing chain rather than appended.
        def set_callback(name, *filter_list, &block)
          type, filters, options = normalize_callback_params(filter_list, block)
          self_chain = get_callbacks name
          mapped = filters.map do |filter|
            Callback.build(self_chain, filter, type, options)
          end

          __update_callbacks(name) do |target, chain|
            options[:prepend] ? chain.prepend(*mapped) : chain.append(*mapped)
            target.set_callbacks name, chain
          end
        end

        # Skip a previously set callback. Like +set_callback+, <tt>:if</tt> or
        # <tt>:unless</tt> options may be passed in order to control when the
        # callback is skipped.
        #
        #   class Writer < Person
        #      skip_callback :validate, :before, :check_membership, if: -> { self.age > 18 }
        #   end
        #
        # An <tt>ArgumentError</tt> will be raised if the callback has not
        # already been set (unless the <tt>:raise</tt> option is set to <tt>false</tt>).
        def skip_callback(name, *filter_list, &block)
          type, filters, options = normalize_callback_params(filter_list, block)
          options[:raise] = true unless options.key?(:raise)

          __update_callbacks(name) do |target, chain|
            filters.each do |filter|
              callback = chain.find {|c| c.matches?(type, filter) }

              if !callback && options[:raise]
                raise ArgumentError, "#{type.to_s.capitalize} #{name} callback #{filter.inspect} has not been defined"
              end

              if callback && (options.key?(:if) || options.key?(:unless))
                new_callback = callback.merge_conditional_options(chain, if_option: options[:if], unless_option: options[:unless])
                chain.insert(chain.index(callback), new_callback)
              end

              chain.delete(callback)
            end
            target.set_callbacks name, chain
          end
        end

        # Remove all set callbacks for the given event.
        def reset_callbacks(name)
          callbacks = get_callbacks name

          ActiveSupport::DescendantsTracker.descendants(self).each do |target|
            chain = target.get_callbacks(name).dup
            callbacks.each { |c| chain.delete(c) }
            target.set_callbacks name, chain
          end

          self.set_callbacks name, callbacks.dup.clear
        end

        # Define sets of events in the object life cycle that support callbacks.
        #
        #   define_callbacks :validate
        #   define_callbacks :initialize, :save, :destroy
        #
        # ===== Options
        #
        # * <tt>:terminator</tt> - Determines when a before filter will halt the
        #   callback chain, preventing following before and around callbacks from
        #   being called and the event from being triggered.
        #   This should be a lambda to be executed.
        #   The current object and the result lambda of the callback will be provided
        #   to the terminator lambda.
        #
        #     define_callbacks :validate, terminator: ->(target, result_lambda) { result_lambda.call == false }
        #
        #   In this example, if any before validate callbacks returns +false+,
        #   any successive before and around callback is not executed.
        #
        #   The default terminator halts the chain when a callback throws +:abort+.
        #
        # * <tt>:skip_after_callbacks_if_terminated</tt> - Determines if after
        #   callbacks should be terminated by the <tt>:terminator</tt> option. By
        #   default after callbacks are executed no matter if callback chain was
        #   terminated or not. This option makes sense only when <tt>:terminator</tt>
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
        #
        # ===== Notes
        #
        # +names+ passed to `define_callbacks` must not end with
        # `!`, `?` or `=`.
        #
        # Calling `define_callbacks` multiple times with the same +names+ will
        # overwrite previous callbacks registered with `set_callback`.
        def define_callbacks(*names)
          options = names.extract_options!

          names.each do |name|
            class_attribute "_#{name}_callbacks", instance_writer: false
            set_callbacks name, CallbackChain.new(name, options)

            module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def _run_#{name}_callbacks(&block)
              __run_callbacks__(_#{name}_callbacks, &block)
            end
          RUBY
          end
        end

        protected

          def get_callbacks(name) # :nodoc:
            send "_#{name}_callbacks"
          end

          def set_callbacks(name, callbacks) # :nodoc:
            send "_#{name}_callbacks=", callbacks
          end

          def deprecated_false_terminator # :nodoc:
            Proc.new do |target, result_lambda|
              terminate = true
              catch(:abort) do
                result = result_lambda.call if result_lambda.is_a?(Proc)
                if Callbacks.halt_and_display_warning_on_return_false && result == false
                  display_deprecation_warning_for_false_terminator
                else
                  terminate = false
                end
              end
              terminate
            end
          end

        private

          def display_deprecation_warning_for_false_terminator
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
          Returning `false` in Active Record and Active Model callbacks will not implicitly halt a callback chain in Rails 5.1.
          To explicitly halt the callback chain, please use `throw :abort` instead.
        MSG
          end
      end
  end
end
