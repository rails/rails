require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/class/inheritable_attributes'

module ActiveSupport
  # Callbacks are hooks into the lifecycle of an object that allow you to trigger logic
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
  #     save_callback :before, :saving_message
  #     def saving_message
  #       puts "saving..."
  #     end
  #
  #     save_callback :after do |object|
  #       puts "saved"
  #     end
  #
  #     def save
  #       _run_save_callbacks do
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
  #     save_callback :before, :prepare
  #     def prepare
  #       puts "preparing save"
  #     end
  #   end
  #
  #   class ConfigStorage < Storage
  #     save_callback :before, :saving_message
  #     def saving_message
  #       puts "saving..."
  #     end
  #
  #     save_callback :after do |object|
  #       puts "saved"
  #     end
  #
  #     def save
  #       _run_save_callbacks do
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
  module NewCallbacks
    def self.included(klass)
      klass.extend ClassMethods
    end
        
    def run_callbacks(kind, options = {}, &blk)
      send("_run_#{kind}_callbacks", &blk)
    end
    
    class Callback
      @@_callback_sequence = 0
      
      attr_accessor :filter, :kind, :name, :options, :per_key, :klass
      def initialize(filter, kind, options, klass, name)
        @kind, @klass = kind, klass
        @name         = name
        
        normalize_options!(options)

        @per_key              = options.delete(:per_key)
        @raw_filter, @options = filter, options
        @filter               = _compile_filter(filter)
        @compiled_options     = _compile_options(options)
        @callback_id          = next_id

        _compile_per_key_options
      end
      
      def clone(klass)
        obj                  = super()
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
      
      def next_id
        @@_callback_sequence += 1
      end
      
      def matches?(_kind, _name, _filter)
        @kind   == _kind &&
        @name   == _name &&
        @filter == _filter
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
      def start(key = nil, options = {})
        object, terminator = (options || {}).values_at(:object, :terminator)
        
        return if key && !object.send("_one_time_conditions_valid_#{@callback_id}?")
        
        terminator ||= false
        
        # options[0] is the compiled form of supplied conditions
        # options[1] is the "end" for the conditional
                
        if @kind == :before || @kind == :around
          if @kind == :before
            # if condition    # before_save :filter_name, :if => :condition
            #   filter_name
            # end
            filter = <<-RUBY_EVAL
              unless halted
                result = #{@filter}
                halted ||= (#{terminator})
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
            
            name = "_conditional_callback_#{@kind}_#{next_id}"
            txt = <<-RUBY_EVAL
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
            @klass.class_eval(txt)
            "#{name}(halted) do"
          end
        end
      end
      
      # This will supply contents for around and after filters, but not
      # before filters (for the backward pass).
      def end(key = nil, options = {})
        object = (options || {})[:object]
        
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
      #   Arrays::  Merged together into a single filter
      #   Symbols:: Already methods
      #   Strings:: class_eval'ed into methods
      #   Procs::   define_method'ed into methods
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
        when Proc
          @klass.send(:define_method, method_name, &filter)
          method_name << (filter.arity == 1 ? "(self)" : "")
        when String
          @klass.class_eval <<-RUBY_EVAL
            def #{method_name}
              #{filter}
            end
          RUBY_EVAL
          method_name
        else
          kind, name = @kind, @name
          @klass.send(:define_method, method_name) do
            filter.send("#{kind}_#{name}", self)
          end
          method_name
        end
      end
    end

    # This method_missing is supplied to catch callbacks with keys and create
    # the appropriate callback for future use.
    def method_missing(meth, *args, &blk)
      if meth.to_s =~ /_run__([\w:]+)__(\w+)__(\w+)__callbacks/
        return self.class._create_and_run_keyed_callback($1, $2.to_sym, $3.to_sym, self, &blk)
      end
      super
    end
    
    # An Array with a compile method
    class CallbackChain < Array
      def initialize(symbol)
        @symbol = symbol
      end
      
      def compile(key = nil, options = {})
        method = []
        method << "halted = false"
        each do |callback|
          method << callback.start(key, options)
        end
        method << "yield self if block_given?"
        reverse_each do |callback|
          method << callback.end(key, options)
        end
        method.compact.join("\n")
      end
      
      def clone(klass)
        chain = CallbackChain.new(@symbol)
        chain.push(*map {|c| c.clone(klass)})
      end
    end
        
    module ClassMethods
      CHAINS = {:before => :before, :around => :before, :after => :after}
      
      # Make the _run_save_callbacks method. The generated method takes
      # a block that it'll yield to. It'll call the before and around filters
      # in order, yield the block, and then run the after filters.
      # 
      # _run_save_callbacks do
      #   save
      # end
      #
      # The _run_save_callbacks method can optionally take a key, which
      # will be used to compile an optimized callback method for each
      # key. See #define_callbacks for more information.
      def _define_runner(symbol, str, options)        
        str = <<-RUBY_EVAL
          def _run_#{symbol}_callbacks(key = nil)
            if key
              name = "_run__\#{self.class.name.split("::").last}__#{symbol}__\#{key}__callbacks"
              
              if respond_to?(name)
                send(name) { yield if block_given? }
              else
                self.class._create_and_run_keyed_callback(
                  self.class.name.split("::").last,
                  :#{symbol}, key, self) { yield if block_given? }
              end
            else
              #{str}
            end
          end
        RUBY_EVAL
  
        undef_method "_run_#{symbol}_callbacks" if method_defined?("_run_#{symbol}_callbacks")
        class_eval str, __FILE__, __LINE__
        
        before_name, around_name, after_name = 
          options.values_at(:before, :after, :around)
      end
      
      # This is called the first time a callback is called with a particular
      # key. It creates a new callback method for the key, calculating
      # which callbacks can be omitted because of per_key conditions.
      def _create_and_run_keyed_callback(klass, kind, key, obj, &blk)
        @_keyed_callbacks ||= {}
        @_keyed_callbacks[[kind, key]] ||= begin
          str = self.send("_#{kind}_callbacks").compile(key, :object => obj, :terminator => self.send("_#{kind}_terminator"))

          self.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def _run__#{klass.split("::").last}__#{kind}__#{key}__callbacks
              #{str}
            end
          RUBY_EVAL
                    
          true
        end
                                  
        obj.send("_run__#{klass.split("::").last}__#{kind}__#{key}__callbacks", &blk)
      end
      
      # Define callbacks.
      #
      # Creates a <name>_callback method that you can use to add callbacks.
      #
      # Syntax:
      #   save_callback :before, :before_meth
      #   save_callback :after,  :after_meth, :if => :condition
      #   save_callback :around {|r| stuff; yield; stuff }
      #
      # The <name>_callback method also updates the _run_<name>_callbacks
      # method, which is the public API to run the callbacks.
      #
      # Also creates a skip_<name>_callback method that you can use to skip
      # callbacks.
      #
      # When creating or skipping callbacks, you can specify conditions that
      # are always the same for a given key. For instance, in ActionPack,
      # we convert :only and :except conditions into per-key conditions.
      #
      #   before_filter :authenticate, :except => "index"
      # becomes
      #   dispatch_callback :before, :authenticate, :per_key => {:unless => proc {|c| c.action_name == "index"}}
      #
      # Per-Key conditions are evaluated only once per use of a given key.
      # In the case of the above example, you would do:
      #
      #   run_dispatch_callbacks(action_name) { ... dispatch stuff ... }
      #
      # In that case, each action_name would get its own compiled callback
      # method that took into consideration the per_key conditions. This
      # is a speed improvement for ActionPack.
      def define_callbacks(*symbols)
        terminator = symbols.pop if symbols.last.is_a?(String)
        symbols.each do |symbol|
          self.extlib_inheritable_accessor("_#{symbol}_terminator")
          self.send("_#{symbol}_terminator=", terminator)
          self.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            extlib_inheritable_accessor :_#{symbol}_callbacks
            self._#{symbol}_callbacks = CallbackChain.new(:#{symbol})

            def self.#{symbol}_callback(*filters, &blk)
              type = [:before, :after, :around].include?(filters.first) ? filters.shift : :before
              options = filters.last.is_a?(Hash) ? filters.pop : {}
              filters.unshift(blk) if block_given?
              
              filters.map! do |filter| 
                # overrides parent class
                self._#{symbol}_callbacks.delete_if {|c| c.matches?(type, :#{symbol}, filter)}
                Callback.new(filter, type, options.dup, self, :#{symbol})
              end
              self._#{symbol}_callbacks.push(*filters)
              _define_runner(:#{symbol}, 
                self._#{symbol}_callbacks.compile(nil, :terminator => _#{symbol}_terminator), 
                options)
            end
            
            def self.skip_#{symbol}_callback(*filters, &blk)
              type = [:before, :after, :around].include?(filters.first) ? filters.shift : :before
              options = filters.last.is_a?(Hash) ? filters.pop : {}
              filters.unshift(blk) if block_given?
              filters.each do |filter|
                self._#{symbol}_callbacks = self._#{symbol}_callbacks.clone(self)
                
                filter = self._#{symbol}_callbacks.find {|c| c.matches?(type, :#{symbol}, filter) }
                per_key = options[:per_key] || {}
                if filter
                  filter.recompile!(options, per_key)
                else
                  self._#{symbol}_callbacks.delete(filter)
                end
                _define_runner(:#{symbol}, 
                  self._#{symbol}_callbacks.compile(nil, :terminator => _#{symbol}_terminator), 
                  options)
              end
              
            end
            
            def self.reset_#{symbol}_callbacks
              self._#{symbol}_callbacks = CallbackChain.new(:#{symbol})
              _define_runner(:#{symbol}, self._#{symbol}_callbacks.compile, {})
            end
            
            self.#{symbol}_callback(:before)
          RUBY_EVAL
        end
      end
    end
  end
end
