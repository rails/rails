require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/hash/transform_values'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/string/filters'
require 'active_support/rescuable'
require 'action_dispatch/http/upload'
require 'rack/test'
require 'stringio'
require 'set'

module ActionController
  # Raised when a required parameter is missing.
  #
  #   params = ActionController::Parameters.new(a: {})
  #   params.fetch(:b)
  #   # => ActionController::ParameterMissing: param is missing or the value is empty: b
  #   params.require(:a)
  #   # => ActionController::ParameterMissing: param is missing or the value is empty: a
  class ParameterMissing < KeyError
    attr_reader :param # :nodoc:

    def initialize(param) # :nodoc:
      @param = param
      super("param is missing or the value is empty: #{param}")
    end
  end

  # Raised when a supplied parameter is not expected and
  # ActionController::Parameters.action_on_unpermitted_parameters
  # is set to <tt>:raise</tt>.
  #
  #   params = ActionController::Parameters.new(a: "123", b: "456")
  #   params.permit(:c)
  #   # => ActionController::UnpermittedParameters: found unpermitted parameters: a, b
  class UnpermittedParameters < IndexError
    attr_reader :params # :nodoc:

    def initialize(params) # :nodoc:
      @params = params
      super("found unpermitted parameter#{'s' if params.size > 1 }: #{params.join(", ")}")
    end
  end

  # == Action Controller \Parameters
  #
  # Allows you to choose which attributes should be whitelisted for mass updating
  # and thus prevent accidentally exposing that which shouldn't be exposed.
  # Provides two methods for this purpose: #require and #permit. The former is
  # used to mark parameters as required. The latter is used to set the parameter
  # as permitted and limit which attributes should be allowed for mass updating.
  #
  #   params = ActionController::Parameters.new({
  #     person: {
  #       name: 'Francesco',
  #       age:  22,
  #       role: 'admin'
  #     }
  #   })
  #
  #   permitted = params.require(:person).permit(:name, :age)
  #   permitted            # => {"name"=>"Francesco", "age"=>22}
  #   permitted.class      # => ActionController::Parameters
  #   permitted.permitted? # => true
  #
  #   Person.first.update!(permitted)
  #   # => #<Person id: 1, name: "Francesco", age: 22, role: "user">
  #
  # It provides two options that controls the top-level behavior of new instances:
  #
  # * +permit_all_parameters+ - If it's +true+, all the parameters will be
  #   permitted by default. The default is +false+.
  # * +action_on_unpermitted_parameters+ - Allow to control the behavior when parameters
  #   that are not explicitly permitted are found. The values can be <tt>:log</tt> to
  #   write a message on the logger or <tt>:raise</tt> to raise
  #   ActionController::UnpermittedParameters exception. The default value is <tt>:log</tt>
  #   in test and development environments, +false+ otherwise.
  #
  # Examples:
  #
  #   params = ActionController::Parameters.new
  #   params.permitted? # => false
  #
  #   ActionController::Parameters.permit_all_parameters = true
  #
  #   params = ActionController::Parameters.new
  #   params.permitted? # => true
  #
  #   params = ActionController::Parameters.new(a: "123", b: "456")
  #   params.permit(:c)
  #   # => {}
  #
  #   ActionController::Parameters.action_on_unpermitted_parameters = :raise
  #
  #   params = ActionController::Parameters.new(a: "123", b: "456")
  #   params.permit(:c)
  #   # => ActionController::UnpermittedParameters: found unpermitted keys: a, b
  #
  # Please note that these options *are not thread-safe*. In a multi-threaded
  # environment they should only be set once at boot-time and never mutated at
  # runtime.
  #
  # You can fetch values of <tt>ActionController::Parameters</tt> using either
  # <tt>:key</tt> or <tt>"key"</tt>.
  #
  #   params = ActionController::Parameters.new(key: 'value')
  #   params[:key]  # => "value"
  #   params["key"] # => "value"
  class Parameters
    cattr_accessor :permit_all_parameters, instance_accessor: false
    cattr_accessor :action_on_unpermitted_parameters, instance_accessor: false

    delegate :keys, :key?, :has_key?, :values, :has_value?, :value?, :empty?, :include?,
      :as_json, to: :@parameters

    # By default, never raise an UnpermittedParameters exception if these
    # params are present. The default includes both 'controller' and 'action'
    # because they are added by Rails and should be of no concern. One way
    # to change these is to specify `always_permitted_parameters` in your
    # config. For instance:
    #
    #    config.always_permitted_parameters = %w( controller action format )
    cattr_accessor :always_permitted_parameters
    self.always_permitted_parameters = %w( controller action )

    # Returns a new instance of <tt>ActionController::Parameters</tt>.
    # Also, sets the +permitted+ attribute to the default value of
    # <tt>ActionController::Parameters.permit_all_parameters</tt>.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   params = ActionController::Parameters.new(name: 'Francesco')
    #   params.permitted?  # => false
    #   Person.new(params) # => ActiveModel::ForbiddenAttributesError
    #
    #   ActionController::Parameters.permit_all_parameters = true
    #
    #   params = ActionController::Parameters.new(name: 'Francesco')
    #   params.permitted?  # => true
    #   Person.new(params) # => #<Person id: nil, name: "Francesco">
    def initialize(parameters = {})
      @parameters = parameters.with_indifferent_access
      @permitted = self.class.permit_all_parameters
    end

    # Returns true if another +Parameters+ object contains the same content and
    # permitted flag.
    def ==(other)
      if other.respond_to?(:permitted?)
        self.permitted? == other.permitted? && self.parameters == other.parameters
      elsif other.is_a?(Hash)
        ActiveSupport::Deprecation.warn <<-WARNING.squish
          Comparing equality between `ActionController::Parameters` and a
          `Hash` is deprecated and will be removed in Rails 5.1. Please only do
          comparisons between instances of `ActionController::Parameters`. If
          you need to compare to a hash, first convert it using
          `ActionController::Parameters#new`.
        WARNING
        @parameters == other.with_indifferent_access
      else
        @parameters == other
      end
    end

    # Returns a safe <tt>ActiveSupport::HashWithIndifferentAccess</tt>
    # representation of this parameter with all unpermitted keys removed.
    #
    #   params = ActionController::Parameters.new({
    #     name: 'Senjougahara Hitagi',
    #     oddity: 'Heavy stone crab'
    #   })
    #   params.to_h # => {}
    #
    #   safe_params = params.permit(:name)
    #   safe_params.to_h # => {"name"=>"Senjougahara Hitagi"}
    def to_h
      if permitted?
        convert_parameters_to_hashes(@parameters, :to_h)
      else
        slice(*self.class.always_permitted_parameters).permit!.to_h
      end
    end

    # Returns an unsafe, unfiltered
    # <tt>ActiveSupport::HashWithIndifferentAccess</tt> representation of this
    # parameter.
    #
    #   params = ActionController::Parameters.new({
    #     name: 'Senjougahara Hitagi',
    #     oddity: 'Heavy stone crab'
    #   })
    #   params.to_unsafe_h
    #   # => {"name"=>"Senjougahara Hitagi", "oddity" => "Heavy stone crab"}
    def to_unsafe_h
      convert_parameters_to_hashes(@parameters, :to_unsafe_h)
    end
    alias_method :to_unsafe_hash, :to_unsafe_h

    # Convert all hashes in values into parameters, then yield each pair in
    # the same way as <tt>Hash#each_pair</tt>
    def each_pair(&block)
      @parameters.each_pair do |key, value|
        yield key, convert_hashes_to_parameters(key, value)
      end
    end
    alias_method :each, :each_pair

    # Attribute that keeps track of converted arrays, if any, to avoid double
    # looping in the common use case permit + mass-assignment. Defined in a
    # method to instantiate it only if needed.
    #
    # Testing membership still loops, but it's going to be faster than our own
    # loop that converts values. Also, we are not going to build a new array
    # object per fetch.
    def converted_arrays
      @converted_arrays ||= Set.new
    end

    # Returns +true+ if the parameter is permitted, +false+ otherwise.
    #
    #   params = ActionController::Parameters.new
    #   params.permitted? # => false
    #   params.permit!
    #   params.permitted? # => true
    def permitted?
      @permitted
    end

    # Sets the +permitted+ attribute to +true+. This can be used to pass
    # mass assignment. Returns +self+.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   params = ActionController::Parameters.new(name: 'Francesco')
    #   params.permitted?  # => false
    #   Person.new(params) # => ActiveModel::ForbiddenAttributesError
    #   params.permit!
    #   params.permitted?  # => true
    #   Person.new(params) # => #<Person id: nil, name: "Francesco">
    def permit!
      each_pair do |key, value|
        Array.wrap(value).each do |v|
          v.permit! if v.respond_to? :permit!
        end
      end

      @permitted = true
      self
    end

    # This method accepts both a single key and an array of keys.
    #
    # When passed a single key, if it exists and its associated value is
    # either present or the singleton +false+, returns said value:
    #
    #   ActionController::Parameters.new(person: { name: 'Francesco' }).require(:person)
    #   # => {"name"=>"Francesco"}
    #
    # Otherwise raises <tt>ActionController::ParameterMissing</tt>:
    #
    #   ActionController::Parameters.new.require(:person)
    #   # ActionController::ParameterMissing: param is missing or the value is empty: person
    #
    #   ActionController::Parameters.new(person: nil).require(:person)
    #   # ActionController::ParameterMissing: param is missing or the value is empty: person
    #
    #   ActionController::Parameters.new(person: "\t").require(:person)
    #   # ActionController::ParameterMissing: param is missing or the value is empty: person
    #
    #   ActionController::Parameters.new(person: {}).require(:person)
    #   # ActionController::ParameterMissing: param is missing or the value is empty: person
    #
    # When given an array of keys, the method tries to require each one of them
    # in order. If it succeeds, an array with the respective return values is
    # returned:
    #
    #   params = ActionController::Parameters.new(user: { ... }, profile: { ... })
    #   user_params, profile_params = params.require(:user, :profile)
    #
    # Otherwise, the method re-raises the first exception found:
    #
    #   params = ActionController::Parameters.new(user: {}, profile: {})
    #   user_params, profile_params = params.require(:user, :profile)
    #   # ActionController::ParameterMissing: param is missing or the value is empty: user
    #
    # Technically this method can be used to fetch terminal values:
    #
    #   # CAREFUL
    #   params = ActionController::Parameters.new(person: { name: 'Finn' })
    #   name = params.require(:person).require(:name) # CAREFUL
    #
    # but take into account that at some point those ones have to be permitted:
    #
    #   def person_params
    #     params.require(:person).permit(:name).tap do |person_params|
    #       person_params.require(:name) # SAFER
    #     end
    #   end
    #
    # for example.
    def require(key)
      return key.map { |k| require(k) } if key.is_a?(Array)
      value = self[key]
      if value.present? || value == false
        value
      else
        raise ParameterMissing.new(key)
      end
    end

    # Alias of #require.
    alias :required :require

    # Returns a new <tt>ActionController::Parameters</tt> instance that
    # includes only the given +filters+ and sets the +permitted+ attribute
    # for the object to +true+. This is useful for limiting which attributes
    # should be allowed for mass updating.
    #
    #   params = ActionController::Parameters.new(user: { name: 'Francesco', age: 22, role: 'admin' })
    #   permitted = params.require(:user).permit(:name, :age)
    #   permitted.permitted?      # => true
    #   permitted.has_key?(:name) # => true
    #   permitted.has_key?(:age)  # => true
    #   permitted.has_key?(:role) # => false
    #
    # Only permitted scalars pass the filter. For example, given
    #
    #   params.permit(:name)
    #
    # +:name+ passes if it is a key of +params+ whose associated value is of type
    # +String+, +Symbol+, +NilClass+, +Numeric+, +TrueClass+, +FalseClass+,
    # +Date+, +Time+, +DateTime+, +StringIO+, +IO+,
    # +ActionDispatch::Http::UploadedFile+ or +Rack::Test::UploadedFile+.
    # Otherwise, the key +:name+ is filtered out.
    #
    # You may declare that the parameter should be an array of permitted scalars
    # by mapping it to an empty array:
    #
    #   params = ActionController::Parameters.new(tags: ['rails', 'parameters'])
    #   params.permit(tags: [])
    #
    # You can also use +permit+ on nested parameters, like:
    #
    #   params = ActionController::Parameters.new({
    #     person: {
    #       name: 'Francesco',
    #       age:  22,
    #       pets: [{
    #         name: 'Purplish',
    #         category: 'dogs'
    #       }]
    #     }
    #   })
    #
    #   permitted = params.permit(person: [ :name, { pets: :name } ])
    #   permitted.permitted?                    # => true
    #   permitted[:person][:name]               # => "Francesco"
    #   permitted[:person][:age]                # => nil
    #   permitted[:person][:pets][0][:name]     # => "Purplish"
    #   permitted[:person][:pets][0][:category] # => nil
    #
    # Note that if you use +permit+ in a key that points to a hash,
    # it won't allow all the hash. You also need to specify which
    # attributes inside the hash should be whitelisted.
    #
    #   params = ActionController::Parameters.new({
    #     person: {
    #       contact: {
    #         email: 'none@test.com',
    #         phone: '555-1234'
    #       }
    #     }
    #   })
    #
    #   params.require(:person).permit(:contact)
    #   # => {}
    #
    #   params.require(:person).permit(contact: :phone)
    #   # => {"contact"=>{"phone"=>"555-1234"}}
    #
    #   params.require(:person).permit(contact: [ :email, :phone ])
    #   # => {"contact"=>{"email"=>"none@test.com", "phone"=>"555-1234"}}
    def permit(*filters)
      params = self.class.new

      filters.flatten.each do |filter|
        case filter
        when Symbol, String
          permitted_scalar_filter(params, filter)
        when Hash then
          hash_filter(params, filter)
        end
      end

      unpermitted_parameters!(params) if self.class.action_on_unpermitted_parameters

      params.permit!
    end

    # Returns a parameter for the given +key+. If not found,
    # returns +nil+.
    #
    #   params = ActionController::Parameters.new(person: { name: 'Francesco' })
    #   params[:person] # => {"name"=>"Francesco"}
    #   params[:none]   # => nil
    def [](key)
      convert_hashes_to_parameters(key, @parameters[key])
    end

    # Assigns a value to a given +key+. The given key may still get filtered out
    # when +permit+ is called.
    def []=(key, value)
      @parameters[key] = value
    end

    # Returns a parameter for the given +key+. If the +key+
    # can't be found, there are several options: With no other arguments,
    # it will raise an <tt>ActionController::ParameterMissing</tt> error;
    # if more arguments are given, then that will be returned; if a block
    # is given, then that will be run and its result returned.
    #
    #   params = ActionController::Parameters.new(person: { name: 'Francesco' })
    #   params.fetch(:person)               # => {"name"=>"Francesco"}
    #   params.fetch(:none)                 # => ActionController::ParameterMissing: param is missing or the value is empty: none
    #   params.fetch(:none, 'Francesco')    # => "Francesco"
    #   params.fetch(:none) { 'Francesco' } # => "Francesco"
    def fetch(key, *args)
      convert_value_to_parameters(
        @parameters.fetch(key) {
          if block_given?
            yield
          else
            args.fetch(0) { raise ActionController::ParameterMissing.new(key) }
          end
        }
      )
    end

    if Hash.method_defined?(:dig)
      # Extracts the nested parameter from the given +keys+ by calling +dig+
      # at each step. Returns +nil+ if any intermediate step is +nil+.
      #
      # params = ActionController::Parameters.new(foo: { bar: { baz: 1 } })
      # params.dig(:foo, :bar, :baz) # => 1
      # params.dig(:foo, :zot, :xyz) # => nil
      #
      # params2 = ActionController::Parameters.new(foo: [10, 11, 12])
      # params2.dig(:foo, 1) # => 11
      def dig(*keys)
        convert_value_to_parameters(@parameters.dig(*keys))
      end
    end

    # Returns a new <tt>ActionController::Parameters</tt> instance that
    # includes only the given +keys+. If the given +keys+
    # don't exist, returns an empty hash.
    #
    #   params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #   params.slice(:a, :b) # => {"a"=>1, "b"=>2}
    #   params.slice(:d)     # => {}
    def slice(*keys)
      new_instance_with_inherited_permitted_status(@parameters.slice(*keys))
    end

    # Returns current <tt>ActionController::Parameters</tt> instance which
    # contains only the given +keys+.
    def slice!(*keys)
      @parameters.slice!(*keys)
      self
    end

    # Returns a new <tt>ActionController::Parameters</tt> instance that
    # filters out the given +keys+.
    #
    #   params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #   params.except(:a, :b) # => {"c"=>3}
    #   params.except(:d)     # => {"a"=>1,"b"=>2,"c"=>3}
    def except(*keys)
      new_instance_with_inherited_permitted_status(@parameters.except(*keys))
    end

    # Removes and returns the key/value pairs matching the given keys.
    #
    #   params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #   params.extract!(:a, :b) # => {"a"=>1, "b"=>2}
    #   params                  # => {"c"=>3}
    def extract!(*keys)
      new_instance_with_inherited_permitted_status(@parameters.extract!(*keys))
    end

    # Returns a new <tt>ActionController::Parameters</tt> with the results of
    # running +block+ once for every value. The keys are unchanged.
    #
    #   params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #   params.transform_values { |x| x * 2 }
    #   # => {"a"=>2, "b"=>4, "c"=>6}
    def transform_values(&block)
      if block
        new_instance_with_inherited_permitted_status(
          @parameters.transform_values(&block)
        )
      else
        @parameters.transform_values
      end
    end

    # Performs values transformation and returns the altered
    # <tt>ActionController::Parameters</tt> instance.
    def transform_values!(&block)
      @parameters.transform_values!(&block)
      self
    end

    # Returns a new <tt>ActionController::Parameters</tt> instance with the
    # results of running +block+ once for every key. The values are unchanged.
    def transform_keys(&block)
      if block
        new_instance_with_inherited_permitted_status(
          @parameters.transform_keys(&block)
        )
      else
        @parameters.transform_keys
      end
    end

    # Performs keys transformation and returns the altered
    # <tt>ActionController::Parameters</tt> instance.
    def transform_keys!(&block)
      @parameters.transform_keys!(&block)
      self
    end

    # Deletes and returns a key-value pair from +Parameters+ whose key is equal
    # to key. If the key is not found, returns the default value. If the
    # optional code block is given and the key is not found, pass in the key
    # and return the result of block.
    def delete(key)
      convert_value_to_parameters(@parameters.delete(key))
    end

    # Returns a new instance of <tt>ActionController::Parameters</tt> with only
    # items that the block evaluates to true.
    def select(&block)
      new_instance_with_inherited_permitted_status(@parameters.select(&block))
    end

    # Equivalent to Hash#keep_if, but returns nil if no changes were made.
    def select!(&block)
      @parameters.select!(&block)
      self
    end
    alias_method :keep_if, :select!

    # Returns a new instance of <tt>ActionController::Parameters</tt> with items
    # that the block evaluates to true removed.
    def reject(&block)
      new_instance_with_inherited_permitted_status(@parameters.reject(&block))
    end

    # Removes items that the block evaluates to true and returns self.
    def reject!(&block)
      @parameters.reject!(&block)
      self
    end
    alias_method :delete_if, :reject!

    # Returns values that were assigned to the given +keys+. Note that all the
    # +Hash+ objects will be converted to <tt>ActionController::Parameters</tt>.
    def values_at(*keys)
      convert_value_to_parameters(@parameters.values_at(*keys))
    end

    # Returns an exact copy of the <tt>ActionController::Parameters</tt>
    # instance. +permitted+ state is kept on the duped object.
    #
    #   params = ActionController::Parameters.new(a: 1)
    #   params.permit!
    #   params.permitted?        # => true
    #   copy_params = params.dup # => {"a"=>1}
    #   copy_params.permitted?   # => true
    def dup
      super.tap do |duplicate|
        duplicate.permitted = @permitted
      end
    end

    # Returns a new <tt>ActionController::Parameters</tt> with all keys from
    # +other_hash+ merges into current hash.
    def merge(other_hash)
      new_instance_with_inherited_permitted_status(
        @parameters.merge(other_hash)
      )
    end

    # This is required by ActiveModel attribute assignment, so that user can
    # pass +Parameters+ to a mass assignment methods in a model. It should not
    # matter as we are using +HashWithIndifferentAccess+ internally.
    def stringify_keys # :nodoc:
      dup
    end

    def inspect
      "<#{self.class} #{@parameters} permitted: #{@permitted}>"
    end

    def method_missing(method_sym, *args, &block)
      if @parameters.respond_to?(method_sym)
        message = <<-DEPRECATE.squish
          Method #{method_sym} is deprecated and will be removed in Rails 5.1,
          as `ActionController::Parameters` no longer inherits from
          hash. Using this deprecated behavior exposes potential security
          problems. If you continue to use this method you may be creating
          a security vulnerability in your app that can be exploited. Instead,
          consider using one of these documented methods which are not
          deprecated: http://api.rubyonrails.org/v#{ActionPack.version}/classes/ActionController/Parameters.html
        DEPRECATE
        ActiveSupport::Deprecation.warn(message)
        @parameters.public_send(method_sym, *args, &block)
      else
        super
      end
    end

    protected
      attr_reader :parameters

      def permitted=(new_permitted)
        @permitted = new_permitted
      end

      def fields_for_style?
        @parameters.all? { |k, v| k =~ /\A-?\d+\z/ && (v.is_a?(Hash) || v.is_a?(Parameters)) }
      end

    private
      def new_instance_with_inherited_permitted_status(hash)
        self.class.new(hash).tap do |new_instance|
          new_instance.permitted = @permitted
        end
      end

      def convert_parameters_to_hashes(value, using)
        case value
        when Array
          value.map { |v| convert_parameters_to_hashes(v, using) }
        when Hash
          value.transform_values do |v|
            convert_parameters_to_hashes(v, using)
          end.with_indifferent_access
        when Parameters
          value.send(using)
        else
          value
        end
      end

      def convert_hashes_to_parameters(key, value)
        converted = convert_value_to_parameters(value)
        @parameters[key] = converted unless converted.equal?(value)
        converted
      end

      def convert_value_to_parameters(value)
        case value
        when Array
          return value if converted_arrays.member?(value)
          converted = value.map { |_| convert_value_to_parameters(_) }
          converted_arrays << converted
          converted
        when Hash
          self.class.new(value)
        else
          value
        end
      end

      def each_element(object)
        case object
        when Array
          object.grep(Parameters).map { |el| yield el }.compact
        when Parameters
          if object.fields_for_style?
            hash = object.class.new
            object.each { |k,v| hash[k] = yield v }
            hash
          else
            yield object
          end
        end
      end

      def unpermitted_parameters!(params)
        unpermitted_keys = unpermitted_keys(params)
        if unpermitted_keys.any?
          case self.class.action_on_unpermitted_parameters
          when :log
            name = "unpermitted_parameters.action_controller"
            ActiveSupport::Notifications.instrument(name, keys: unpermitted_keys)
          when :raise
            raise ActionController::UnpermittedParameters.new(unpermitted_keys)
          end
        end
      end

      def unpermitted_keys(params)
        self.keys - params.keys - self.always_permitted_parameters
      end

      #
      # --- Filtering ----------------------------------------------------------
      #

      # This is a white list of permitted scalar types that includes the ones
      # supported in XML and JSON requests.
      #
      # This list is in particular used to filter ordinary requests, String goes
      # as first element to quickly short-circuit the common case.
      #
      # If you modify this collection please update the API of +permit+ above.
      PERMITTED_SCALAR_TYPES = [
        String,
        Symbol,
        NilClass,
        Numeric,
        TrueClass,
        FalseClass,
        Date,
        Time,
        # DateTimes are Dates, we document the type but avoid the redundant check.
        StringIO,
        IO,
        ActionDispatch::Http::UploadedFile,
        Rack::Test::UploadedFile,
      ]

      def permitted_scalar?(value)
        PERMITTED_SCALAR_TYPES.any? {|type| value.is_a?(type)}
      end

      def permitted_scalar_filter(params, key)
        if has_key?(key) && permitted_scalar?(self[key])
          params[key] = self[key]
        end

        keys.grep(/\A#{Regexp.escape(key)}\(\d+[if]?\)\z/) do |k|
          if permitted_scalar?(self[k])
            params[k] = self[k]
          end
        end
      end

      def array_of_permitted_scalars?(value)
        if value.is_a?(Array) && value.all? {|element| permitted_scalar?(element)}
          yield value
        end
      end

      def non_scalar?(value)
        value.is_a?(Array) || value.is_a?(Parameters)
      end

      EMPTY_ARRAY = []
      def hash_filter(params, filter)
        filter = filter.with_indifferent_access

        # Slicing filters out non-declared keys.
        slice(*filter.keys).each do |key, value|
          next unless value
          next unless has_key? key

          if filter[key] == EMPTY_ARRAY
            # Declaration { comment_ids: [] }.
            array_of_permitted_scalars?(self[key]) do |val|
              params[key] = val
            end
          elsif non_scalar?(value)
            # Declaration { user: :name } or { user: [:name, :age, { address: ... }] }.
            params[key] = each_element(value) do |element|
              element.permit(*Array.wrap(filter[key]))
            end
          end
        end
      end
  end

  # == Strong \Parameters
  #
  # It provides an interface for protecting attributes from end-user
  # assignment. This makes Action Controller parameters forbidden
  # to be used in Active Model mass assignment until they have been
  # whitelisted.
  #
  # In addition, parameters can be marked as required and flow through a
  # predefined raise/rescue flow to end up as a 400 Bad Request with no
  # effort.
  #
  #   class PeopleController < ActionController::Base
  #     # Using "Person.create(params[:person])" would raise an
  #     # ActiveModel::ForbiddenAttributesError exception because it'd
  #     # be using mass assignment without an explicit permit step.
  #     # This is the recommended form:
  #     def create
  #       Person.create(person_params)
  #     end
  #
  #     # This will pass with flying colors as long as there's a person key in the
  #     # parameters, otherwise it'll raise an ActionController::MissingParameter
  #     # exception, which will get caught by ActionController::Base and turned
  #     # into a 400 Bad Request reply.
  #     def update
  #       redirect_to current_account.people.find(params[:id]).tap { |person|
  #         person.update!(person_params)
  #       }
  #     end
  #
  #     private
  #       # Using a private method to encapsulate the permissible parameters is
  #       # just a good pattern since you'll be able to reuse the same permit
  #       # list between create and update. Also, you can specialize this method
  #       # with per-user checking of permissible attributes.
  #       def person_params
  #         params.require(:person).permit(:name, :age)
  #       end
  #   end
  #
  # In order to use <tt>accepts_nested_attributes_for</tt> with Strong \Parameters, you
  # will need to specify which nested attributes should be whitelisted. You might want
  # to allow +:id+ and +:_destroy+, see ActiveRecord::NestedAttributes for more information.
  #
  #   class Person
  #     has_many :pets
  #     accepts_nested_attributes_for :pets
  #   end
  #
  #   class PeopleController < ActionController::Base
  #     def create
  #       Person.create(person_params)
  #     end
  #
  #     ...
  #
  #     private
  #
  #       def person_params
  #         # It's mandatory to specify the nested attributes that should be whitelisted.
  #         # If you use `permit` with just the key that points to the nested attributes hash,
  #         # it will return an empty hash.
  #         params.require(:person).permit(:name, :age, pets_attributes: [ :id, :name, :category ])
  #       end
  #   end
  #
  # See ActionController::Parameters.require and ActionController::Parameters.permit
  # for more information.
  module StrongParameters
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    # Returns a new ActionController::Parameters object that
    # has been instantiated with the <tt>request.parameters</tt>.
    def params
      @_params ||= Parameters.new(request.parameters)
    end

    # Assigns the given +value+ to the +params+ hash. If +value+
    # is a Hash, this will create an ActionController::Parameters
    # object that has been instantiated with the given +value+ hash.
    def params=(value)
      @_params = value.is_a?(Hash) ? Parameters.new(value) : value
    end
  end
end
