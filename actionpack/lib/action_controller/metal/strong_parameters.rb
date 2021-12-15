# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/array/wrap"
require "active_support/core_ext/string/filters"
require "active_support/core_ext/object/to_query"
require "action_dispatch/http/upload"
require "rack/test"
require "stringio"
require "set"
require "yaml"

module ActionController
  # Raised when a required parameter is missing.
  #
  #   params = ActionController::Parameters.new(a: {})
  #   params.fetch(:b)
  #   # => ActionController::ParameterMissing: param is missing or the value is empty: b
  #   params.require(:a)
  #   # => ActionController::ParameterMissing: param is missing or the value is empty: a
  class ParameterMissing < KeyError
    attr_reader :param, :keys # :nodoc:

    def initialize(param, keys = nil) # :nodoc:
      @param = param
      @keys  = keys
      super("param is missing or the value is empty: #{param}")
    end

    if defined?(DidYouMean::Correctable) && defined?(DidYouMean::SpellChecker)
      include DidYouMean::Correctable # :nodoc:

      def corrections # :nodoc:
        @corrections ||= DidYouMean::SpellChecker.new(dictionary: keys).correct(param.to_s)
      end
    end
  end

  # Raised when a supplied parameter is not expected and
  # ActionController::Parameters.action_on_unpermitted_parameters
  # is set to <tt>:raise</tt>.
  #
  #   params = ActionController::Parameters.new(a: "123", b: "456")
  #   params.permit(:c)
  #   # => ActionController::UnpermittedParameters: found unpermitted parameters: :a, :b
  class UnpermittedParameters < IndexError
    attr_reader :params # :nodoc:

    def initialize(params) # :nodoc:
      @params = params
      super("found unpermitted parameter#{'s' if params.size > 1 }: #{params.map { |e| ":#{e}" }.join(", ")}")
    end
  end

  # Raised when a Parameters instance is not marked as permitted and
  # an operation to transform it to hash is called.
  #
  #   params = ActionController::Parameters.new(a: "123", b: "456")
  #   params.to_h
  #   # => ActionController::UnfilteredParameters: unable to convert unpermitted parameters to hash
  class UnfilteredParameters < ArgumentError
    def initialize # :nodoc:
      super("unable to convert unpermitted parameters to hash")
    end
  end

  # == Action Controller \Parameters
  #
  # Allows you to choose which attributes should be permitted for mass updating
  # and thus prevent accidentally exposing that which shouldn't be exposed.
  # Provides two methods for this purpose: #require and #permit. The former is
  # used to mark parameters as required. The latter is used to set the parameter
  # as permitted and limit which attributes should be allowed for mass updating.
  #
  #   params = ActionController::Parameters.new({
  #     person: {
  #       name: "Francesco",
  #       age:  22,
  #       role: "admin"
  #     }
  #   })
  #
  #   permitted = params.require(:person).permit(:name, :age)
  #   permitted            # => #<ActionController::Parameters {"name"=>"Francesco", "age"=>22} permitted: true>
  #   permitted.permitted? # => true
  #
  #   Person.first.update!(permitted)
  #   # => #<Person id: 1, name: "Francesco", age: 22, role: "user">
  #
  # It provides two options that controls the top-level behavior of new instances:
  #
  # * +permit_all_parameters+ - If it's +true+, all the parameters will be
  #   permitted by default. The default is +false+.
  # * +action_on_unpermitted_parameters+ - Controls behavior when parameters that are not explicitly
  #    permitted are found. The default value is <tt>:log</tt> in test and development environments,
  #    +false+ otherwise. The values can be:
  #   * +false+ to take no action.
  #   * <tt>:log</tt> to emit an <tt>ActiveSupport::Notifications.instrument</tt> event on the
  #     <tt>unpermitted_parameters.action_controller</tt> topic and log at the DEBUG level.
  #   * <tt>:raise</tt> to raise a <tt>ActionController::UnpermittedParameters</tt> exception.
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
  #   # => #<ActionController::Parameters {} permitted: true>
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
  #   params = ActionController::Parameters.new(key: "value")
  #   params[:key]  # => "value"
  #   params["key"] # => "value"
  class Parameters
    cattr_accessor :permit_all_parameters, instance_accessor: false, default: false

    cattr_accessor :action_on_unpermitted_parameters, instance_accessor: false

    ##
    # :method: as_json
    #
    # :call-seq:
    #   as_json(options=nil)
    #
    # Returns a hash that can be used as the JSON representation for the parameters.

    ##
    # :method: each_key
    #
    # :call-seq:
    #   each_key()
    #
    # Calls block once for each key in the parameters, passing the key.
    # If no block is given, an enumerator is returned instead.

    ##
    # :method: empty?
    #
    # :call-seq:
    #   empty?()
    #
    # Returns true if the parameters have no key/value pairs.

    ##
    # :method: has_key?
    #
    # :call-seq:
    #   has_key?(key)
    #
    # Returns true if the given key is present in the parameters.

    ##
    # :method: has_value?
    #
    # :call-seq:
    #   has_value?(value)
    #
    # Returns true if the given value is present for some key in the parameters.

    ##
    # :method: include?
    #
    # :call-seq:
    #   include?(key)
    #
    # Returns true if the given key is present in the parameters.

    ##
    # :method: key?
    #
    # :call-seq:
    #   key?(key)
    #
    # Returns true if the given key is present in the parameters.

    ##
    # :method: member?
    #
    # :call-seq:
    #   member?(key)
    #
    # Returns true if the given key is present in the parameters.

    ##
    # :method: keys
    #
    # :call-seq:
    #   keys()
    #
    # Returns a new array of the keys of the parameters.

    ##
    # :method: to_s
    #
    # :call-seq:
    #   to_s()
    #
    # Returns the content of the parameters as a string.

    ##
    # :method: value?
    #
    # :call-seq:
    #   value?(value)
    #
    # Returns true if the given value is present for some key in the parameters.

    ##
    # :method: values
    #
    # :call-seq:
    #   values()
    #
    # Returns a new array of the values of the parameters.
    delegate :keys, :key?, :has_key?, :member?, :values, :has_value?, :value?, :empty?, :include?,
      :as_json, :to_s, :each_key, to: :@parameters

    # By default, never raise an UnpermittedParameters exception if these
    # params are present. The default includes both 'controller' and 'action'
    # because they are added by Rails and should be of no concern. One way
    # to change these is to specify `always_permitted_parameters` in your
    # config. For instance:
    #
    #    config.action_controller.always_permitted_parameters = %w( controller action format )
    cattr_accessor :always_permitted_parameters, default: %w( controller action )

    class << self
      def nested_attribute?(key, value) # :nodoc:
        /\A-?\d+\z/.match?(key) && (value.is_a?(Hash) || value.is_a?(Parameters))
      end
    end

    # Returns a new instance of <tt>ActionController::Parameters</tt>.
    # Also, sets the +permitted+ attribute to the default value of
    # <tt>ActionController::Parameters.permit_all_parameters</tt>.
    #
    #   class Person < ActiveRecord::Base
    #   end
    #
    #   params = ActionController::Parameters.new(name: "Francesco")
    #   params.permitted?  # => false
    #   Person.new(params) # => ActiveModel::ForbiddenAttributesError
    #
    #   ActionController::Parameters.permit_all_parameters = true
    #
    #   params = ActionController::Parameters.new(name: "Francesco")
    #   params.permitted?  # => true
    #   Person.new(params) # => #<Person id: nil, name: "Francesco">
    def initialize(parameters = {}, logging_context = {})
      @parameters = parameters.with_indifferent_access
      @logging_context = logging_context
      @permitted = self.class.permit_all_parameters
    end

    # Returns true if another +Parameters+ object contains the same content and
    # permitted flag.
    def ==(other)
      if other.respond_to?(:permitted?)
        permitted? == other.permitted? && parameters == other.parameters
      else
        @parameters == other
      end
    end
    alias eql? ==

    def hash
      [@parameters.hash, @permitted].hash
    end

    # Returns a safe <tt>ActiveSupport::HashWithIndifferentAccess</tt>
    # representation of the parameters with all unpermitted keys removed.
    #
    #   params = ActionController::Parameters.new({
    #     name: "Senjougahara Hitagi",
    #     oddity: "Heavy stone crab"
    #   })
    #   params.to_h
    #   # => ActionController::UnfilteredParameters: unable to convert unpermitted parameters to hash
    #
    #   safe_params = params.permit(:name)
    #   safe_params.to_h # => {"name"=>"Senjougahara Hitagi"}
    def to_h
      if permitted?
        convert_parameters_to_hashes(@parameters, :to_h)
      else
        raise UnfilteredParameters
      end
    end

    # Returns a safe <tt>Hash</tt> representation of the parameters
    # with all unpermitted keys removed.
    #
    #   params = ActionController::Parameters.new({
    #     name: "Senjougahara Hitagi",
    #     oddity: "Heavy stone crab"
    #   })
    #   params.to_hash
    #   # => ActionController::UnfilteredParameters: unable to convert unpermitted parameters to hash
    #
    #   safe_params = params.permit(:name)
    #   safe_params.to_hash # => {"name"=>"Senjougahara Hitagi"}
    def to_hash
      to_h.to_hash
    end

    # Returns a string representation of the receiver suitable for use as a URL
    # query string:
    #
    #   params = ActionController::Parameters.new({
    #     name: "David",
    #     nationality: "Danish"
    #   })
    #   params.to_query
    #   # => ActionController::UnfilteredParameters: unable to convert unpermitted parameters to hash
    #
    #   safe_params = params.permit(:name, :nationality)
    #   safe_params.to_query
    #   # => "name=David&nationality=Danish"
    #
    # An optional namespace can be passed to enclose key names:
    #
    #   params = ActionController::Parameters.new({
    #     name: "David",
    #     nationality: "Danish"
    #   })
    #   safe_params = params.permit(:name, :nationality)
    #   safe_params.to_query("user")
    #   # => "user%5Bname%5D=David&user%5Bnationality%5D=Danish"
    #
    # The string pairs "key=value" that conform the query string
    # are sorted lexicographically in ascending order.
    #
    # This method is also aliased as +to_param+.
    def to_query(*args)
      to_h.to_query(*args)
    end
    alias_method :to_param, :to_query

    # Returns an unsafe, unfiltered
    # <tt>ActiveSupport::HashWithIndifferentAccess</tt> representation of the
    # parameters.
    #
    #   params = ActionController::Parameters.new({
    #     name: "Senjougahara Hitagi",
    #     oddity: "Heavy stone crab"
    #   })
    #   params.to_unsafe_h
    #   # => {"name"=>"Senjougahara Hitagi", "oddity" => "Heavy stone crab"}
    def to_unsafe_h
      convert_parameters_to_hashes(@parameters, :to_unsafe_h)
    end
    alias_method :to_unsafe_hash, :to_unsafe_h

    # Convert all hashes in values into parameters, then yield each pair in
    # the same way as <tt>Hash#each_pair</tt>.
    def each_pair(&block)
      return to_enum(__callee__) unless block_given?
      @parameters.each_pair do |key, value|
        yield [key, convert_hashes_to_parameters(key, value)]
      end

      self
    end
    alias_method :each, :each_pair

    # Convert all hashes in values into parameters, then yield each value in
    # the same way as <tt>Hash#each_value</tt>.
    def each_value(&block)
      return to_enum(:each_value) unless block_given?
      @parameters.each_pair do |key, value|
        yield convert_hashes_to_parameters(key, value)
      end

      self
    end

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
    #   params = ActionController::Parameters.new(name: "Francesco")
    #   params.permitted?  # => false
    #   Person.new(params) # => ActiveModel::ForbiddenAttributesError
    #   params.permit!
    #   params.permitted?  # => true
    #   Person.new(params) # => #<Person id: nil, name: "Francesco">
    def permit!
      each_pair do |key, value|
        Array.wrap(value).flatten.each do |v|
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
    #   ActionController::Parameters.new(person: { name: "Francesco" }).require(:person)
    #   # => #<ActionController::Parameters {"name"=>"Francesco"} permitted: false>
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
    #   user_params, profile_params = params.require([:user, :profile])
    #
    # Otherwise, the method re-raises the first exception found:
    #
    #   params = ActionController::Parameters.new(user: {}, profile: {})
    #   user_params, profile_params = params.require([:user, :profile])
    #   # ActionController::ParameterMissing: param is missing or the value is empty: user
    #
    # Technically this method can be used to fetch terminal values:
    #
    #   # CAREFUL
    #   params = ActionController::Parameters.new(person: { name: "Finn" })
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
        raise ParameterMissing.new(key, @parameters.keys)
      end
    end

    # Alias of #require.
    alias :required :require

    # Returns a new <tt>ActionController::Parameters</tt> instance that
    # includes only the given +filters+ and sets the +permitted+ attribute
    # for the object to +true+. This is useful for limiting which attributes
    # should be allowed for mass updating.
    #
    #   params = ActionController::Parameters.new(user: { name: "Francesco", age: 22, role: "admin" })
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
    #   params = ActionController::Parameters.new(tags: ["rails", "parameters"])
    #   params.permit(tags: [])
    #
    # Sometimes it is not possible or convenient to declare the valid keys of
    # a hash parameter or its internal structure. Just map to an empty hash:
    #
    #   params.permit(preferences: {})
    #
    # Be careful because this opens the door to arbitrary input. In this
    # case, +permit+ ensures values in the returned structure are permitted
    # scalars and filters out anything else.
    #
    # You can also use +permit+ on nested parameters, like:
    #
    #   params = ActionController::Parameters.new({
    #     person: {
    #       name: "Francesco",
    #       age:  22,
    #       pets: [{
    #         name: "Purplish",
    #         category: "dogs"
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
    # attributes inside the hash should be permitted.
    #
    #   params = ActionController::Parameters.new({
    #     person: {
    #       contact: {
    #         email: "none@test.com",
    #         phone: "555-1234"
    #       }
    #     }
    #   })
    #
    #   params.require(:person).permit(:contact)
    #   # => #<ActionController::Parameters {} permitted: true>
    #
    #   params.require(:person).permit(contact: :phone)
    #   # => #<ActionController::Parameters {"contact"=>#<ActionController::Parameters {"phone"=>"555-1234"} permitted: true>} permitted: true>
    #
    #   params.require(:person).permit(contact: [ :email, :phone ])
    #   # => #<ActionController::Parameters {"contact"=>#<ActionController::Parameters {"email"=>"none@test.com", "phone"=>"555-1234"} permitted: true>} permitted: true>
    #
    # If your parameters specify multiple parameters indexed by a number,
    # you can permit each set of parameters under the numeric key to be the same using the same syntax as permitting a single item.
    #
    #   params = ActionController::Parameters.new({
    #     person: {
    #       '0': {
    #         email: "none@test.com",
    #         phone: "555-1234"
    #       },
    #       '1': {
    #         email: "nothing@test.com",
    #         phone: "555-6789"
    #       },
    #     }
    #   })
    #   params.permit(person: [:email]).to_h
    #   # => {"person"=>{"0"=>{"email"=>"none@test.com"}, "1"=>{"email"=>"nothing@test.com"}}}
    #
    # If you want to specify what keys you want from each numeric key, you can instead specify each one individually
    #
    #   params = ActionController::Parameters.new({
    #     person: {
    #       '0': {
    #         email: "none@test.com",
    #         phone: "555-1234"
    #       },
    #       '1': {
    #         email: "nothing@test.com",
    #         phone: "555-6789"
    #       },
    #     }
    #   })
    #   params.permit(person: { '0': [:email], '1': [:phone]}).to_h
    #   # => {"person"=>{"0"=>{"email"=>"none@test.com"}, "1"=>{"phone"=>"555-6789"}}}
    def permit(*filters)
      params = self.class.new

      filters.flatten.each do |filter|
        case filter
        when Symbol, String
          permitted_scalar_filter(params, filter)
        when Hash
          hash_filter(params, filter)
        end
      end

      unpermitted_parameters!(params) if self.class.action_on_unpermitted_parameters

      params.permit!
    end

    # Returns a parameter for the given +key+. If not found,
    # returns +nil+.
    #
    #   params = ActionController::Parameters.new(person: { name: "Francesco" })
    #   params[:person] # => #<ActionController::Parameters {"name"=>"Francesco"} permitted: false>
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
    # if a second argument is given, then that is returned (converted to an
    # instance of ActionController::Parameters if possible); if a block
    # is given, then that will be run and its result returned.
    #
    #   params = ActionController::Parameters.new(person: { name: "Francesco" })
    #   params.fetch(:person)               # => #<ActionController::Parameters {"name"=>"Francesco"} permitted: false>
    #   params.fetch(:none)                 # => ActionController::ParameterMissing: param is missing or the value is empty: none
    #   params.fetch(:none, {})             # => #<ActionController::Parameters {} permitted: false>
    #   params.fetch(:none, "Francesco")    # => "Francesco"
    #   params.fetch(:none) { "Francesco" } # => "Francesco"
    def fetch(key, *args)
      convert_value_to_parameters(
        @parameters.fetch(key) {
          if block_given?
            yield
          else
            args.fetch(0) { raise ActionController::ParameterMissing.new(key, @parameters.keys) }
          end
        }
      )
    end

    # Extracts the nested parameter from the given +keys+ by calling +dig+
    # at each step. Returns +nil+ if any intermediate step is +nil+.
    #
    #   params = ActionController::Parameters.new(foo: { bar: { baz: 1 } })
    #   params.dig(:foo, :bar, :baz) # => 1
    #   params.dig(:foo, :zot, :xyz) # => nil
    #
    #   params2 = ActionController::Parameters.new(foo: [10, 11, 12])
    #   params2.dig(:foo, 1) # => 11
    def dig(*keys)
      convert_hashes_to_parameters(keys.first, @parameters[keys.first])
      @parameters.dig(*keys)
    end

    # Returns a new <tt>ActionController::Parameters</tt> instance that
    # includes only the given +keys+. If the given +keys+
    # don't exist, returns an empty hash.
    #
    #   params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #   params.slice(:a, :b) # => #<ActionController::Parameters {"a"=>1, "b"=>2} permitted: false>
    #   params.slice(:d)     # => #<ActionController::Parameters {} permitted: false>
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
    #   params.except(:a, :b) # => #<ActionController::Parameters {"c"=>3} permitted: false>
    #   params.except(:d)     # => #<ActionController::Parameters {"a"=>1, "b"=>2, "c"=>3} permitted: false>
    def except(*keys)
      new_instance_with_inherited_permitted_status(@parameters.except(*keys))
    end

    # Removes and returns the key/value pairs matching the given keys.
    #
    #   params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #   params.extract!(:a, :b) # => #<ActionController::Parameters {"a"=>1, "b"=>2} permitted: false>
    #   params                  # => #<ActionController::Parameters {"c"=>3} permitted: false>
    def extract!(*keys)
      new_instance_with_inherited_permitted_status(@parameters.extract!(*keys))
    end

    # Returns a new <tt>ActionController::Parameters</tt> with the results of
    # running +block+ once for every value. The keys are unchanged.
    #
    #   params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #   params.transform_values { |x| x * 2 }
    #   # => #<ActionController::Parameters {"a"=>2, "b"=>4, "c"=>6} permitted: false>
    def transform_values
      return to_enum(:transform_values) unless block_given?
      new_instance_with_inherited_permitted_status(
        @parameters.transform_values { |v| yield convert_value_to_parameters(v) }
      )
    end

    # Performs values transformation and returns the altered
    # <tt>ActionController::Parameters</tt> instance.
    def transform_values!
      return to_enum(:transform_values!) unless block_given?
      @parameters.transform_values! { |v| yield convert_value_to_parameters(v) }
      self
    end

    # Returns a new <tt>ActionController::Parameters</tt> instance with the
    # results of running +block+ once for every key. The values are unchanged.
    def transform_keys(&block)
      return to_enum(:transform_keys) unless block_given?
      new_instance_with_inherited_permitted_status(
        @parameters.transform_keys(&block)
      )
    end

    # Performs keys transformation and returns the altered
    # <tt>ActionController::Parameters</tt> instance.
    def transform_keys!(&block)
      return to_enum(:transform_keys!) unless block_given?
      @parameters.transform_keys!(&block)
      self
    end

    # Returns a new <tt>ActionController::Parameters</tt> instance with the
    # results of running +block+ once for every key. This includes the keys
    # from the root hash and from all nested hashes and arrays. The values are unchanged.
    def deep_transform_keys(&block)
      new_instance_with_inherited_permitted_status(
        @parameters.deep_transform_keys(&block)
      )
    end

    # Returns the <tt>ActionController::Parameters</tt> instance changing its keys.
    # This includes the keys from the root hash and from all nested hashes and arrays.
    # The values are unchanged.
    def deep_transform_keys!(&block)
      @parameters.deep_transform_keys!(&block)
      self
    end

    # Deletes a key-value pair from +Parameters+ and returns the value. If
    # +key+ is not found, returns +nil+ (or, with optional code block, yields
    # +key+ and returns the result). Cf. +#extract!+, which returns the
    # corresponding +ActionController::Parameters+ object.
    def delete(key, &block)
      convert_value_to_parameters(@parameters.delete(key, &block))
    end

    # Returns a new instance of <tt>ActionController::Parameters</tt> with only
    # items that the block evaluates to true.
    def select(&block)
      new_instance_with_inherited_permitted_status(@parameters.select(&block))
    end

    # Equivalent to Hash#keep_if, but returns +nil+ if no changes were made.
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

    # Returns a new instance of <tt>ActionController::Parameters</tt> with +nil+ values removed.
    def compact
      new_instance_with_inherited_permitted_status(@parameters.compact)
    end

    # Removes all +nil+ values in place and returns +self+, or +nil+ if no changes were made.
    def compact!
      self if @parameters.compact!
    end

    # Returns a new instance of <tt>ActionController::Parameters</tt> without the blank values.
    # Uses Object#blank? for determining if a value is blank.
    def compact_blank
      reject { |_k, v| v.blank? }
    end

    # Removes all blank values in place and returns self.
    # Uses Object#blank? for determining if a value is blank.
    def compact_blank!
      reject! { |_k, v| v.blank? }
    end

    # Returns values that were assigned to the given +keys+. Note that all the
    # +Hash+ objects will be converted to <tt>ActionController::Parameters</tt>.
    def values_at(*keys)
      convert_value_to_parameters(@parameters.values_at(*keys))
    end

    # Returns a new <tt>ActionController::Parameters</tt> with all keys from
    # +other_hash+ merged into current hash.
    def merge(other_hash)
      new_instance_with_inherited_permitted_status(
        @parameters.merge(other_hash.to_h)
      )
    end

    # Returns current <tt>ActionController::Parameters</tt> instance with
    # +other_hash+ merged into current hash.
    def merge!(other_hash)
      @parameters.merge!(other_hash.to_h)
      self
    end

    # Returns a new <tt>ActionController::Parameters</tt> with all keys from
    # current hash merged into +other_hash+.
    def reverse_merge(other_hash)
      new_instance_with_inherited_permitted_status(
        other_hash.to_h.merge(@parameters)
      )
    end
    alias_method :with_defaults, :reverse_merge

    # Returns current <tt>ActionController::Parameters</tt> instance with
    # current hash merged into +other_hash+.
    def reverse_merge!(other_hash)
      @parameters.merge!(other_hash.to_h) { |key, left, right| left }
      self
    end
    alias_method :with_defaults!, :reverse_merge!

    # This is required by ActiveModel attribute assignment, so that user can
    # pass +Parameters+ to a mass assignment methods in a model. It should not
    # matter as we are using +HashWithIndifferentAccess+ internally.
    def stringify_keys # :nodoc:
      dup
    end

    def inspect
      "#<#{self.class} #{@parameters} permitted: #{@permitted}>"
    end

    def self.hook_into_yaml_loading # :nodoc:
      # Wire up YAML format compatibility with Rails 4.2 and Psych 2.0.8 and 2.0.9+.
      # Makes the YAML parser call `init_with` when it encounters the keys below
      # instead of trying its own parsing routines.
      YAML.load_tags["!ruby/hash-with-ivars:ActionController::Parameters"] = name
      YAML.load_tags["!ruby/hash:ActionController::Parameters"] = name
    end
    hook_into_yaml_loading

    def init_with(coder) # :nodoc:
      case coder.tag
      when "!ruby/hash:ActionController::Parameters"
        # YAML 2.0.8's format where hash instance variables weren't stored.
        @parameters = coder.map.with_indifferent_access
        @permitted  = false
      when "!ruby/hash-with-ivars:ActionController::Parameters"
        # YAML 2.0.9's Hash subclass format where keys and values
        # were stored under an elements hash and `permitted` within an ivars hash.
        @parameters = coder.map["elements"].with_indifferent_access
        @permitted  = coder.map["ivars"][:@permitted]
      when "!ruby/object:ActionController::Parameters"
        # YAML's Object format. Only needed because of the format
        # backwards compatibility above, otherwise equivalent to YAML's initialization.
        @parameters, @permitted = coder.map["parameters"], coder.map["permitted"]
      end
    end

    # Returns duplicate of object including all parameters.
    def deep_dup
      self.class.new(@parameters.deep_dup).tap do |duplicate|
        duplicate.permitted = @permitted
      end
    end

    protected
      attr_reader :parameters

      attr_writer :permitted

      def nested_attributes?
        @parameters.any? { |k, v| Parameters.nested_attribute?(k, v) }
      end

      def each_nested_attribute
        hash = self.class.new
        self.each { |k, v| hash[k] = yield v if Parameters.nested_attribute?(k, v) }
        hash
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
          converted_arrays << converted.dup
          converted
        when Hash
          self.class.new(value)
        else
          value
        end
      end

      def specify_numeric_keys?(filter)
        if filter.respond_to?(:keys)
          filter.keys.any? { |key| /\A-?\d+\z/.match?(key) }
        end
      end

      def each_element(object, filter, &block)
        case object
        when Array
          object.grep(Parameters).filter_map(&block)
        when Parameters
          if object.nested_attributes? && !specify_numeric_keys?(filter)
            object.each_nested_attribute(&block)
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
            ActiveSupport::Notifications.instrument(name, keys: unpermitted_keys, context: @logging_context)
          when :raise
            raise ActionController::UnpermittedParameters.new(unpermitted_keys)
          end
        end
      end

      def unpermitted_keys(params)
        keys - params.keys - always_permitted_parameters
      end

      #
      # --- Filtering ----------------------------------------------------------
      #

      # This is a list of permitted scalar types that includes the ones
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
        PERMITTED_SCALAR_TYPES.any? { |type| value.is_a?(type) }
      end

      # Adds existing keys to the params if their values are scalar.
      #
      # For example:
      #
      #   puts self.keys #=> ["zipcode(90210i)"]
      #   params = {}
      #
      #   permitted_scalar_filter(params, "zipcode")
      #
      #   puts params.keys # => ["zipcode"]
      def permitted_scalar_filter(params, permitted_key)
        permitted_key = permitted_key.to_s

        if has_key?(permitted_key) && permitted_scalar?(self[permitted_key])
          params[permitted_key] = self[permitted_key]
        end

        each_key do |key|
          next unless key =~ /\(\d+[if]?\)\z/
          next unless $~.pre_match == permitted_key

          params[key] = self[key] if permitted_scalar?(self[key])
        end
      end

      def array_of_permitted_scalars?(value)
        if value.is_a?(Array) && value.all? { |element| permitted_scalar?(element) }
          yield value
        end
      end

      def non_scalar?(value)
        value.is_a?(Array) || value.is_a?(Parameters)
      end

      EMPTY_ARRAY = []
      EMPTY_HASH  = {}
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
          elsif filter[key] == EMPTY_HASH
            # Declaration { preferences: {} }.
            if value.is_a?(Parameters)
              params[key] = permit_any_in_parameters(value)
            end
          elsif non_scalar?(value)
            # Declaration { user: :name } or { user: [:name, :age, { address: ... }] }.
            params[key] = each_element(value, filter[key]) do |element|
              element.permit(*Array.wrap(filter[key]))
            end
          end
        end
      end

      def permit_any_in_parameters(params)
        self.class.new.tap do |sanitized|
          params.each do |key, value|
            case value
            when ->(v) { permitted_scalar?(v) }
              sanitized[key] = value
            when Array
              sanitized[key] = permit_any_in_array(value)
            when Parameters
              sanitized[key] = permit_any_in_parameters(value)
            else
              # Filter this one out.
            end
          end
        end
      end

      def permit_any_in_array(array)
        [].tap do |sanitized|
          array.each do |element|
            case element
            when ->(e) { permitted_scalar?(e) }
              sanitized << element
            when Parameters
              sanitized << permit_any_in_parameters(element)
            else
              # Filter this one out.
            end
          end
        end
      end

      def initialize_copy(source)
        super
        @parameters = @parameters.dup
      end
  end

  # == Strong \Parameters
  #
  # It provides an interface for protecting attributes from end-user
  # assignment. This makes Action Controller parameters forbidden
  # to be used in Active Model mass assignment until they have been explicitly
  # enumerated.
  #
  # In addition, parameters can be marked as required and flow through a
  # predefined raise/rescue flow to end up as a <tt>400 Bad Request</tt> with no
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
  #     # parameters, otherwise it'll raise an ActionController::ParameterMissing
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
  #       # a good pattern since you'll be able to reuse the same permit
  #       # list between create and update. Also, you can specialize this method
  #       # with per-user checking of permissible attributes.
  #       def person_params
  #         params.require(:person).permit(:name, :age)
  #       end
  #   end
  #
  # In order to use <tt>accepts_nested_attributes_for</tt> with Strong \Parameters, you
  # will need to specify which nested attributes should be permitted. You might want
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
  #         # It's mandatory to specify the nested attributes that should be permitted.
  #         # If you use `permit` with just the key that points to the nested attributes hash,
  #         # it will return an empty hash.
  #         params.require(:person).permit(:name, :age, pets_attributes: [ :id, :name, :category ])
  #       end
  #   end
  #
  # See ActionController::Parameters.require and ActionController::Parameters.permit
  # for more information.
  module StrongParameters
    # Returns a new ActionController::Parameters object that
    # has been instantiated with the <tt>request.parameters</tt>.
    def params
      @_params ||= begin
        context = {
          controller: self.class.name,
          action: action_name,
          request: request,
          params: request.filtered_parameters
        }
        Parameters.new(request.parameters, context)
      end
    end

    # Assigns the given +value+ to the +params+ hash. If +value+
    # is a Hash, this will create an ActionController::Parameters
    # object that has been instantiated with the given +value+ hash.
    def params=(value)
      @_params = value.is_a?(Hash) ? Parameters.new(value) : value
    end
  end
end
