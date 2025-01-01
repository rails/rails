# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/array/wrap"
require "active_support/core_ext/string/filters"
require "active_support/core_ext/object/to_query"
require "active_support/deep_mergeable"
require "action_dispatch/http/upload"
require "rack/test"
require "stringio"
require "yaml"

module ActionController
  # Raised when a required parameter is missing.
  #
  #     params = ActionController::Parameters.new(a: {})
  #     params.fetch(:b)
  #     # => ActionController::ParameterMissing: param is missing or the value is empty or invalid: b
  #     params.require(:a)
  #     # => ActionController::ParameterMissing: param is missing or the value is empty or invalid: a
  #     params.expect(a: [])
  #     # => ActionController::ParameterMissing: param is missing or the value is empty or invalid: a
  class ParameterMissing < KeyError
    attr_reader :param, :keys # :nodoc:

    def initialize(param, keys = nil) # :nodoc:
      @param = param
      @keys  = keys
      super("param is missing or the value is empty or invalid: #{param}")
    end

    if defined?(DidYouMean::Correctable) && defined?(DidYouMean::SpellChecker)
      include DidYouMean::Correctable # :nodoc:

      def corrections # :nodoc:
        @corrections ||= DidYouMean::SpellChecker.new(dictionary: keys).correct(param.to_s)
      end
    end
  end

  # Raised from `expect!` when an expected parameter is missing or is of an
  # incompatible type.
  #
  #     params = ActionController::Parameters.new(a: {})
  #     params.expect!(:a)
  #     # => ActionController::ExpectedParameterMissing: param is missing or the value is empty or invalid: a
  class ExpectedParameterMissing < ParameterMissing
  end

  # Raised when a supplied parameter is not expected and
  # ActionController::Parameters.action_on_unpermitted_parameters is set to
  # `:raise`.
  #
  #     params = ActionController::Parameters.new(a: "123", b: "456")
  #     params.permit(:c)
  #     # => ActionController::UnpermittedParameters: found unpermitted parameters: :a, :b
  class UnpermittedParameters < IndexError
    attr_reader :params # :nodoc:

    def initialize(params) # :nodoc:
      @params = params
      super("found unpermitted parameter#{'s' if params.size > 1 }: #{params.map { |e| ":#{e}" }.join(", ")}")
    end
  end

  # Raised when a Parameters instance is not marked as permitted and an operation
  # to transform it to hash is called.
  #
  #     params = ActionController::Parameters.new(a: "123", b: "456")
  #     params.to_h
  #     # => ActionController::UnfilteredParameters: unable to convert unpermitted parameters to hash
  class UnfilteredParameters < ArgumentError
    def initialize # :nodoc:
      super("unable to convert unpermitted parameters to hash")
    end
  end

  # Raised when initializing Parameters with keys that aren't strings or symbols.
  #
  #     ActionController::Parameters.new(123 => 456)
  #     # => ActionController::InvalidParameterKey: all keys must be Strings or Symbols, got: Integer
  class InvalidParameterKey < ArgumentError
  end

  # # Action Controller Parameters
  #
  # Allows you to choose which attributes should be permitted for mass updating
  # and thus prevent accidentally exposing that which shouldn't be exposed.
  #
  # Provides methods for filtering and requiring params:
  #
  # *   `expect` to safely permit and require parameters in one step.
  # *   `permit` to filter params for mass assignment.
  # *   `require` to require a parameter or raise an error.
  #
  # Examples:
  #
  #     params = ActionController::Parameters.new({
  #       person: {
  #         name: "Francesco",
  #         age:  22,
  #         role: "admin"
  #       }
  #     })
  #
  #     permitted = params.expect(person: [:name, :age])
  #     permitted # => #<ActionController::Parameters {"name"=>"Francesco", "age"=>22} permitted: true>
  #
  #     Person.first.update!(permitted)
  #     # => #<Person id: 1, name: "Francesco", age: 22, role: "user">
  #
  # Parameters provides two options that control the top-level behavior of new
  # instances:
  #
  # *   `permit_all_parameters` - If it's `true`, all the parameters will be
  #     permitted by default. The default is `false`.
  # *   `action_on_unpermitted_parameters` - Controls behavior when parameters
  #     that are not explicitly permitted are found. The default value is `:log`
  #     in test and development environments, `false` otherwise. The values can
  #     be:
  #     *   `false` to take no action.
  #     *   `:log` to emit an `ActiveSupport::Notifications.instrument` event on
  #         the `unpermitted_parameters.action_controller` topic and log at the
  #         DEBUG level.
  #     *   `:raise` to raise an ActionController::UnpermittedParameters
  #         exception.
  #
  # Examples:
  #
  #     params = ActionController::Parameters.new
  #     params.permitted? # => false
  #
  #     ActionController::Parameters.permit_all_parameters = true
  #
  #     params = ActionController::Parameters.new
  #     params.permitted? # => true
  #
  #     params = ActionController::Parameters.new(a: "123", b: "456")
  #     params.permit(:c)
  #     # => #<ActionController::Parameters {} permitted: true>
  #
  #     ActionController::Parameters.action_on_unpermitted_parameters = :raise
  #
  #     params = ActionController::Parameters.new(a: "123", b: "456")
  #     params.permit(:c)
  #     # => ActionController::UnpermittedParameters: found unpermitted keys: a, b
  #
  # Please note that these options *are not thread-safe*. In a multi-threaded
  # environment they should only be set once at boot-time and never mutated at
  # runtime.
  #
  # You can fetch values of `ActionController::Parameters` using either `:key` or
  # `"key"`.
  #
  #     params = ActionController::Parameters.new(key: "value")
  #     params[:key]  # => "value"
  #     params["key"] # => "value"
  class Parameters
    include ActiveSupport::DeepMergeable

    cattr_accessor :permit_all_parameters, instance_accessor: false, default: false

    cattr_accessor :action_on_unpermitted_parameters, instance_accessor: false

    ##
    # :method: deep_merge
    #
    # :call-seq:
    #     deep_merge(other_hash, &block)
    #
    # Returns a new `ActionController::Parameters` instance with `self` and
    # `other_hash` merged recursively.
    #
    # Like with `Hash#merge` in the standard library, a block can be provided to
    # merge values.
    #
    #--
    # Implemented by ActiveSupport::DeepMergeable#deep_merge.

    ##
    # :method: deep_merge!
    #
    # :call-seq:
    #     deep_merge!(other_hash, &block)
    #
    # Same as `#deep_merge`, but modifies `self`.
    #
    #--
    # Implemented by ActiveSupport::DeepMergeable#deep_merge!.

    ##
    # :method: as_json
    #
    # :call-seq:
    #     as_json(options=nil)
    #
    # Returns a hash that can be used as the JSON representation for the parameters.

    ##
    # :method: each_key
    #
    # :call-seq:
    #     each_key(&block)
    #
    # Calls block once for each key in the parameters, passing the key. If no block
    # is given, an enumerator is returned instead.

    ##
    # :method: empty?
    #
    # :call-seq:
    #     empty?()
    #
    # Returns true if the parameters have no key/value pairs.

    ##
    # :method: exclude?
    #
    # :call-seq:
    #     exclude?(key)
    #
    # Returns true if the given key is not present in the parameters.

    ##
    # :method: include?
    #
    # :call-seq:
    #     include?(key)
    #
    # Returns true if the given key is present in the parameters.

    ##
    # :method: keys
    #
    # :call-seq:
    #     keys()
    #
    # Returns a new array of the keys of the parameters.

    ##
    # :method: to_s
    #
    # :call-seq:
    #     to_s()
    #
    # Returns the content of the parameters as a string.

    delegate :keys, :empty?, :exclude?, :include?,
      :as_json, :to_s, :each_key, to: :@parameters

    alias_method :has_key?, :include?
    alias_method :key?, :include?
    alias_method :member?, :include?

    # By default, never raise an UnpermittedParameters exception if these params are
    # present. The default includes both 'controller' and 'action' because they are
    # added by Rails and should be of no concern. One way to change these is to
    # specify `always_permitted_parameters` in your config. For instance:
    #
    #     config.action_controller.always_permitted_parameters = %w( controller action format )
    cattr_accessor :always_permitted_parameters, default: %w( controller action )

    class << self
      def nested_attribute?(key, value) # :nodoc:
        /\A-?\d+\z/.match?(key) && (value.is_a?(Hash) || value.is_a?(Parameters))
      end
    end

    # Returns a new `ActionController::Parameters` instance. Also, sets the
    # `permitted` attribute to the default value of
    # `ActionController::Parameters.permit_all_parameters`.
    #
    #     class Person < ActiveRecord::Base
    #     end
    #
    #     params = ActionController::Parameters.new(name: "Francesco")
    #     params.permitted?  # => false
    #     Person.new(params) # => ActiveModel::ForbiddenAttributesError
    #
    #     ActionController::Parameters.permit_all_parameters = true
    #
    #     params = ActionController::Parameters.new(name: "Francesco")
    #     params.permitted?  # => true
    #     Person.new(params) # => #<Person id: nil, name: "Francesco">
    def initialize(parameters = {}, logging_context = {})
      parameters.each_key do |key|
        unless key.is_a?(String) || key.is_a?(Symbol)
          raise InvalidParameterKey, "all keys must be Strings or Symbols, got: #{key.class}"
        end
      end

      @parameters = parameters.with_indifferent_access
      @logging_context = logging_context
      @permitted = self.class.permit_all_parameters
    end

    # Returns true if another `Parameters` object contains the same content and
    # permitted flag.
    def ==(other)
      if other.respond_to?(:permitted?)
        permitted? == other.permitted? && parameters == other.parameters
      else
        super
      end
    end

    def eql?(other)
      self.class == other.class &&
        permitted? == other.permitted? &&
        parameters.eql?(other.parameters)
    end

    def hash
      [self.class, @parameters, @permitted].hash
    end

    # Returns a safe ActiveSupport::HashWithIndifferentAccess representation of the
    # parameters with all unpermitted keys removed.
    #
    #     params = ActionController::Parameters.new({
    #       name: "Senjougahara Hitagi",
    #       oddity: "Heavy stone crab"
    #     })
    #     params.to_h
    #     # => ActionController::UnfilteredParameters: unable to convert unpermitted parameters to hash
    #
    #     safe_params = params.permit(:name)
    #     safe_params.to_h # => {"name"=>"Senjougahara Hitagi"}
    def to_h(&block)
      if permitted?
        convert_parameters_to_hashes(@parameters, :to_h, &block)
      else
        raise UnfilteredParameters
      end
    end

    # Returns a safe `Hash` representation of the parameters with all unpermitted
    # keys removed.
    #
    #     params = ActionController::Parameters.new({
    #       name: "Senjougahara Hitagi",
    #       oddity: "Heavy stone crab"
    #     })
    #     params.to_hash
    #     # => ActionController::UnfilteredParameters: unable to convert unpermitted parameters to hash
    #
    #     safe_params = params.permit(:name)
    #     safe_params.to_hash # => {"name"=>"Senjougahara Hitagi"}
    def to_hash
      to_h.to_hash
    end

    # Returns a string representation of the receiver suitable for use as a URL
    # query string:
    #
    #     params = ActionController::Parameters.new({
    #       name: "David",
    #       nationality: "Danish"
    #     })
    #     params.to_query
    #     # => ActionController::UnfilteredParameters: unable to convert unpermitted parameters to hash
    #
    #     safe_params = params.permit(:name, :nationality)
    #     safe_params.to_query
    #     # => "name=David&nationality=Danish"
    #
    # An optional namespace can be passed to enclose key names:
    #
    #     params = ActionController::Parameters.new({
    #       name: "David",
    #       nationality: "Danish"
    #     })
    #     safe_params = params.permit(:name, :nationality)
    #     safe_params.to_query("user")
    #     # => "user%5Bname%5D=David&user%5Bnationality%5D=Danish"
    #
    # The string pairs `"key=value"` that conform the query string are sorted
    # lexicographically in ascending order.
    def to_query(*args)
      to_h.to_query(*args)
    end
    alias_method :to_param, :to_query

    # Returns an unsafe, unfiltered ActiveSupport::HashWithIndifferentAccess
    # representation of the parameters.
    #
    #     params = ActionController::Parameters.new({
    #       name: "Senjougahara Hitagi",
    #       oddity: "Heavy stone crab"
    #     })
    #     params.to_unsafe_h
    #     # => {"name"=>"Senjougahara Hitagi", "oddity" => "Heavy stone crab"}
    def to_unsafe_h
      convert_parameters_to_hashes(@parameters, :to_unsafe_h)
    end
    alias_method :to_unsafe_hash, :to_unsafe_h

    # Convert all hashes in values into parameters, then yield each pair in the same
    # way as `Hash#each_pair`.
    def each_pair(&block)
      return to_enum(__callee__) unless block_given?
      @parameters.each_pair do |key, value|
        yield [key, convert_hashes_to_parameters(key, value)]
      end

      self
    end
    alias_method :each, :each_pair

    # Convert all hashes in values into parameters, then yield each value in the
    # same way as `Hash#each_value`.
    def each_value(&block)
      return to_enum(:each_value) unless block_given?
      @parameters.each_pair do |key, value|
        yield convert_hashes_to_parameters(key, value)
      end

      self
    end

    # Returns a new array of the values of the parameters.
    def values
      to_enum(:each_value).to_a
    end

    # Attribute that keeps track of converted arrays, if any, to avoid double
    # looping in the common use case permit + mass-assignment. Defined in a method
    # to instantiate it only if needed.
    #
    # Testing membership still loops, but it's going to be faster than our own loop
    # that converts values. Also, we are not going to build a new array object per
    # fetch.
    def converted_arrays
      @converted_arrays ||= Set.new
    end

    # Returns `true` if the parameter is permitted, `false` otherwise.
    #
    #     params = ActionController::Parameters.new
    #     params.permitted? # => false
    #     params.permit!
    #     params.permitted? # => true
    def permitted?
      @permitted
    end

    # Sets the `permitted` attribute to `true`. This can be used to pass mass
    # assignment. Returns `self`.
    #
    #     class Person < ActiveRecord::Base
    #     end
    #
    #     params = ActionController::Parameters.new(name: "Francesco")
    #     params.permitted?  # => false
    #     Person.new(params) # => ActiveModel::ForbiddenAttributesError
    #     params.permit!
    #     params.permitted?  # => true
    #     Person.new(params) # => #<Person id: nil, name: "Francesco">
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
    # When passed a single key, if it exists and its associated value is either
    # present or the singleton `false`, returns said value:
    #
    #     ActionController::Parameters.new(person: { name: "Francesco" }).require(:person)
    #     # => #<ActionController::Parameters {"name"=>"Francesco"} permitted: false>
    #
    # Otherwise raises ActionController::ParameterMissing:
    #
    #     ActionController::Parameters.new.require(:person)
    #     # ActionController::ParameterMissing: param is missing or the value is empty or invalid: person
    #
    #     ActionController::Parameters.new(person: nil).require(:person)
    #     # ActionController::ParameterMissing: param is missing or the value is empty or invalid: person
    #
    #     ActionController::Parameters.new(person: "\t").require(:person)
    #     # ActionController::ParameterMissing: param is missing or the value is empty or invalid: person
    #
    #     ActionController::Parameters.new(person: {}).require(:person)
    #     # ActionController::ParameterMissing: param is missing or the value is empty or invalid: person
    #
    # When given an array of keys, the method tries to require each one of them in
    # order. If it succeeds, an array with the respective return values is returned:
    #
    #     params = ActionController::Parameters.new(user: { ... }, profile: { ... })
    #     user_params, profile_params = params.require([:user, :profile])
    #
    # Otherwise, the method re-raises the first exception found:
    #
    #     params = ActionController::Parameters.new(user: {}, profile: {})
    #     user_params, profile_params = params.require([:user, :profile])
    #     # ActionController::ParameterMissing: param is missing or the value is empty or invalid: user
    #
    # This method is not recommended for fetching terminal values because it does
    # not permit the values. For example, this can cause problems:
    #
    #     # CAREFUL
    #     params = ActionController::Parameters.new(person: { name: "Finn" })
    #     name = params.require(:person).require(:name) # CAREFUL
    #
    # It is recommended to use `expect` instead:
    #
    #     def person_params
    #       params.expect(person: :name).require(:name)
    #     end
    #
    def require(key)
      return key.map { |k| require(k) } if key.is_a?(Array)
      value = self[key]
      if value.present? || value == false
        value
      else
        raise ParameterMissing.new(key, @parameters.keys)
      end
    end

    alias :required :require

    # Returns a new `ActionController::Parameters` instance that includes only the
    # given `filters` and sets the `permitted` attribute for the object to `true`.
    # This is useful for limiting which attributes should be allowed for mass
    # updating.
    #
    #     params = ActionController::Parameters.new(name: "Francesco", age: 22, role: "admin")
    #     permitted = params.permit(:name, :age)
    #     permitted.permitted?      # => true
    #     permitted.has_key?(:name) # => true
    #     permitted.has_key?(:age)  # => true
    #     permitted.has_key?(:role) # => false
    #
    # Only permitted scalars pass the filter. For example, given
    #
    #     params.permit(:name)
    #
    # `:name` passes if it is a key of `params` whose associated value is of type
    # `String`, `Symbol`, `NilClass`, `Numeric`, `TrueClass`, `FalseClass`, `Date`,
    # `Time`, `DateTime`, `StringIO`, `IO`, ActionDispatch::Http::UploadedFile or
    # `Rack::Test::UploadedFile`. Otherwise, the key `:name` is filtered out.
    #
    # You may declare that the parameter should be an array of permitted scalars by
    # mapping it to an empty array:
    #
    #     params = ActionController::Parameters.new(tags: ["rails", "parameters"])
    #     params.permit(tags: [])
    #
    # Sometimes it is not possible or convenient to declare the valid keys of a hash
    # parameter or its internal structure. Just map to an empty hash:
    #
    #     params.permit(preferences: {})
    #
    # Be careful because this opens the door to arbitrary input. In this case,
    # `permit` ensures values in the returned structure are permitted scalars and
    # filters out anything else.
    #
    # You can also use `permit` on nested parameters:
    #
    #     params = ActionController::Parameters.new({
    #       person: {
    #         name: "Francesco",
    #         age:  22,
    #         pets: [{
    #           name: "Purplish",
    #           category: "dogs"
    #         }]
    #       }
    #     })
    #
    #     permitted = params.permit(person: [ :name, { pets: :name } ])
    #     permitted.permitted?                    # => true
    #     permitted[:person][:name]               # => "Francesco"
    #     permitted[:person][:age]                # => nil
    #     permitted[:person][:pets][0][:name]     # => "Purplish"
    #     permitted[:person][:pets][0][:category] # => nil
    #
    # This has the added benefit of rejecting user-modified inputs that send a
    # string when a hash is expected.
    #
    # When followed by `require`, you can both filter and require parameters
    # following the typical pattern of a Rails form. The `expect` method was
    # made specifically for this use case and is the recommended way to require
    # and permit parameters.
    #
    #      permitted = params.expect(person: [:name, :age])
    #
    # When using `permit` and `require` separately, pay careful attention to the
    # order of the method calls.
    #
    #      params = ActionController::Parameters.new(person: { name: "Martin", age: 40, role: "admin" })
    #      permitted = params.permit(person: [:name, :age]).require(:person) # correct
    #
    # When require is used first, it is possible for users of your application to
    # trigger a NoMethodError when the user, for example, sends a string for :person.
    #
    #      params = ActionController::Parameters.new(person: "tampered")
    #      permitted = params.require(:person).permit(:name, :age) # not recommended
    #      # => NoMethodError: undefined method `permit' for an instance of String
    #
    # Note that if you use `permit` in a key that points to a hash, it won't allow
    # all the hash. You also need to specify which attributes inside the hash should
    # be permitted.
    #
    #     params = ActionController::Parameters.new({
    #       person: {
    #         contact: {
    #           email: "none@test.com",
    #           phone: "555-1234"
    #         }
    #       }
    #     })
    #
    #     params.permit(person: :contact).require(:person)
    #     # => ActionController::ParameterMissing: param is missing or the value is empty or invalid: person
    #
    #     params.permit(person: { contact: :phone }).require(:person)
    #     # => #<ActionController::Parameters {"contact"=>#<ActionController::Parameters {"phone"=>"555-1234"} permitted: true>} permitted: true>
    #
    #     params.permit(person: { contact: [ :email, :phone ] }).require(:person)
    #     # => #<ActionController::Parameters {"contact"=>#<ActionController::Parameters {"email"=>"none@test.com", "phone"=>"555-1234"} permitted: true>} permitted: true>
    #
    # If your parameters specify multiple parameters indexed by a number, you can
    # permit each set of parameters under the numeric key to be the same using the
    # same syntax as permitting a single item.
    #
    #     params = ActionController::Parameters.new({
    #       person: {
    #         '0': {
    #           email: "none@test.com",
    #           phone: "555-1234"
    #         },
    #         '1': {
    #           email: "nothing@test.com",
    #           phone: "555-6789"
    #         },
    #       }
    #     })
    #     params.permit(person: [:email]).to_h
    #     # => {"person"=>{"0"=>{"email"=>"none@test.com"}, "1"=>{"email"=>"nothing@test.com"}}}
    #
    # If you want to specify what keys you want from each numeric key, you can
    # instead specify each one individually
    #
    #     params = ActionController::Parameters.new({
    #       person: {
    #         '0': {
    #           email: "none@test.com",
    #           phone: "555-1234"
    #         },
    #         '1': {
    #           email: "nothing@test.com",
    #           phone: "555-6789"
    #         },
    #       }
    #     })
    #     params.permit(person: { '0': [:email], '1': [:phone]}).to_h
    #     # => {"person"=>{"0"=>{"email"=>"none@test.com"}, "1"=>{"phone"=>"555-6789"}}}
    def permit(*filters)
      permit_filters(filters, on_unpermitted: self.class.action_on_unpermitted_parameters, explicit_arrays: false)
    end

    # `expect` is the preferred way to require and permit parameters.
    # It is safer than the previous recommendation to call `permit` and `require`
    # in sequence, which could allow user triggered 500 errors.
    #
    # `expect` is more strict with types to avoid a number of potential pitfalls
    # that may be encountered with the `.require.permit` pattern.
    #
    # For example:
    #
    #     params = ActionController::Parameters.new(comment: { text: "hello" })
    #     params.expect(comment: [:text])
    #     # => #<ActionController::Parameters { text: "hello" } permitted: true>
    #
    #     params = ActionController::Parameters.new(comment: [{ text: "hello" }, { text: "world" }])
    #     params.expect(comment: [:text])
    #     # => ActionController::ParameterMissing: param is missing or the value is empty or invalid: comment
    #
    # In order to permit an array of parameters, the array must be defined
    # explicitly. Use double array brackets, an array inside an array, to
    # declare that an array of parameters is expected.
    #
    #     params = ActionController::Parameters.new(comments: [{ text: "hello" }, { text: "world" }])
    #     params.expect(comments: [[:text]])
    #     # => [#<ActionController::Parameters { "text" => "hello" } permitted: true>,
    #     #     #<ActionController::Parameters { "text" => "world" } permitted: true>]
    #
    #     params = ActionController::Parameters.new(comments: { text: "hello" })
    #     params.expect(comments: [[:text]])
    #     # => ActionController::ParameterMissing: param is missing or the value is empty or invalid: comments
    #
    # `expect` is intended to protect against array tampering.
    #
    #     params = ActionController::Parameters.new(user: "hack")
    #     # The previous way of requiring and permitting parameters will error
    #     params.require(:user).permit(:name, pets: [:name]) # wrong
    #     # => NoMethodError: undefined method `permit' for an instance of String
    #
    #     # similarly with nested parameters
    #     params = ActionController::Parameters.new(user: { name: "Martin", pets: { name: "hack" } })
    #     user_params = params.require(:user).permit(:name, pets: [:name]) # wrong
    #     # user_params[:pets] is expected to be an array but is a hash
    #
    # `expect` solves this by being more strict with types.
    #
    #     params = ActionController::Parameters.new(user: "hack")
    #     params.expect(user: [ :name, pets: [[:name]] ])
    #     # => ActionController::ParameterMissing: param is missing or the value is empty or invalid: user
    #
    #     # with nested parameters
    #     params = ActionController::Parameters.new(user: { name: "Martin", pets: { name: "hack" } })
    #     user_params = params.expect(user: [:name, pets: [[:name]] ])
    #     user_params[:pets] # => nil
    #
    # As the examples show, `expect` requires the `:user` key, and any root keys
    # similar to the `.require.permit` pattern. If multiple root keys are
    # expected, they will all be required.
    #
    #     params = ActionController::Parameters.new(name: "Martin", pies: [{ type: "dessert", flavor: "pumpkin"}])
    #     name, pies = params.expect(:name, pies: [[:type, :flavor]])
    #     name # => "Martin"
    #     pies # => [#<ActionController::Parameters {"type"=>"dessert", "flavor"=>"pumpkin"} permitted: true>]
    #
    # When called with a hash with multiple keys, `expect` will permit the
    # parameters and require the keys in the order they are given in the hash,
    # returning an array of the permitted parameters.
    #
    #     params = ActionController::Parameters.new(subject: { name: "Martin" }, object: { pie: "pumpkin" })
    #     subject, object = params.expect(subject: [:name], object: [:pie])
    #     subject # => #<ActionController::Parameters {"name"=>"Martin"} permitted: true>
    #     object  # => #<ActionController::Parameters {"pie"=>"pumpkin"} permitted: true>
    #
    # Besides being more strict about array vs hash params, `expect` uses permit
    # internally, so it will behave similarly.
    #
    #     params = ActionController::Parameters.new({
    #       person: {
    #         name: "Francesco",
    #         age:  22,
    #         pets: [{
    #           name: "Purplish",
    #           category: "dogs"
    #         }]
    #       }
    #     })
    #
    #     permitted = params.expect(person: [ :name, { pets: [[:name]] } ])
    #     permitted.permitted?           # => true
    #     permitted[:name]               # => "Francesco"
    #     permitted[:age]                # => nil
    #     permitted[:pets][0][:name]     # => "Purplish"
    #     permitted[:pets][0][:category] # => nil
    #
    # An array of permitted scalars may be expected with the following:
    #
    #     params = ActionController::Parameters.new(tags: ["rails", "parameters"])
    #     permitted = params.expect(tags: [])
    #     permitted.permitted?      # => true
    #     permitted.is_a?(Array)    # => true
    #     permitted.size            # => 2
    #
    def expect(*filters)
      params = permit_filters(filters)
      keys = filters.flatten.flat_map { |f| f.is_a?(Hash) ? f.keys : f }
      values = params.require(keys)
      values.size == 1 ? values.first : values
    end

    # Same as `expect`, but raises an `ActionController::ExpectedParameterMissing`
    # instead of `ActionController::ParameterMissing`. Unlike `expect` which
    # will render a 400 response, `expect!` will raise an exception that is
    # not handled. This is intended for debugging invalid params for an
    # internal API where incorrectly formatted params would indicate a bug
    # in a client library that should be fixed.
    #
    def expect!(*filters)
      expect(*filters)
    rescue ParameterMissing => e
      raise ExpectedParameterMissing.new(e.param, e.keys)
    end

    # Returns a parameter for the given `key`. If not found, returns `nil`.
    #
    #     params = ActionController::Parameters.new(person: { name: "Francesco" })
    #     params[:person] # => #<ActionController::Parameters {"name"=>"Francesco"} permitted: false>
    #     params[:none]   # => nil
    def [](key)
      convert_hashes_to_parameters(key, @parameters[key])
    end

    # Assigns a value to a given `key`. The given key may still get filtered out
    # when #permit is called.
    def []=(key, value)
      @parameters[key] = value
    end

    # Returns a parameter for the given `key`. If the `key` can't be found, there
    # are several options: With no other arguments, it will raise an
    # ActionController::ParameterMissing error; if a second argument is given, then
    # that is returned (converted to an instance of `ActionController::Parameters`
    # if possible); if a block is given, then that will be run and its result
    # returned.
    #
    #     params = ActionController::Parameters.new(person: { name: "Francesco" })
    #     params.fetch(:person)               # => #<ActionController::Parameters {"name"=>"Francesco"} permitted: false>
    #     params.fetch(:none)                 # => ActionController::ParameterMissing: param is missing or the value is empty or invalid: none
    #     params.fetch(:none, {})             # => #<ActionController::Parameters {} permitted: false>
    #     params.fetch(:none, "Francesco")    # => "Francesco"
    #     params.fetch(:none) { "Francesco" } # => "Francesco"
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

    # Extracts the nested parameter from the given `keys` by calling `dig` at each
    # step. Returns `nil` if any intermediate step is `nil`.
    #
    #     params = ActionController::Parameters.new(foo: { bar: { baz: 1 } })
    #     params.dig(:foo, :bar, :baz) # => 1
    #     params.dig(:foo, :zot, :xyz) # => nil
    #
    #     params2 = ActionController::Parameters.new(foo: [10, 11, 12])
    #     params2.dig(:foo, 1) # => 11
    def dig(*keys)
      convert_hashes_to_parameters(keys.first, @parameters[keys.first])
      @parameters.dig(*keys)
    end

    # Returns a new `ActionController::Parameters` instance that includes only the
    # given `keys`. If the given `keys` don't exist, returns an empty hash.
    #
    #     params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #     params.slice(:a, :b) # => #<ActionController::Parameters {"a"=>1, "b"=>2} permitted: false>
    #     params.slice(:d)     # => #<ActionController::Parameters {} permitted: false>
    def slice(*keys)
      new_instance_with_inherited_permitted_status(@parameters.slice(*keys))
    end

    # Returns the current `ActionController::Parameters` instance which contains
    # only the given `keys`.
    def slice!(*keys)
      @parameters.slice!(*keys)
      self
    end

    # Returns a new `ActionController::Parameters` instance that filters out the
    # given `keys`.
    #
    #     params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #     params.except(:a, :b) # => #<ActionController::Parameters {"c"=>3} permitted: false>
    #     params.except(:d)     # => #<ActionController::Parameters {"a"=>1, "b"=>2, "c"=>3} permitted: false>
    def except(*keys)
      new_instance_with_inherited_permitted_status(@parameters.except(*keys))
    end
    alias_method :without, :except

    # Removes and returns the key/value pairs matching the given keys.
    #
    #     params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #     params.extract!(:a, :b) # => #<ActionController::Parameters {"a"=>1, "b"=>2} permitted: false>
    #     params                  # => #<ActionController::Parameters {"c"=>3} permitted: false>
    def extract!(*keys)
      new_instance_with_inherited_permitted_status(@parameters.extract!(*keys))
    end

    # Returns a new `ActionController::Parameters` instance with the results of
    # running `block` once for every value. The keys are unchanged.
    #
    #     params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #     params.transform_values { |x| x * 2 }
    #     # => #<ActionController::Parameters {"a"=>2, "b"=>4, "c"=>6} permitted: false>
    def transform_values
      return to_enum(:transform_values) unless block_given?
      new_instance_with_inherited_permitted_status(
        @parameters.transform_values { |v| yield convert_value_to_parameters(v) }
      )
    end

    # Performs values transformation and returns the altered
    # `ActionController::Parameters` instance.
    def transform_values!
      return to_enum(:transform_values!) unless block_given?
      @parameters.transform_values! { |v| yield convert_value_to_parameters(v) }
      self
    end

    # Returns a new `ActionController::Parameters` instance with the results of
    # running `block` once for every key. The values are unchanged.
    def transform_keys(&block)
      return to_enum(:transform_keys) unless block_given?
      new_instance_with_inherited_permitted_status(
        @parameters.transform_keys(&block)
      )
    end

    # Performs keys transformation and returns the altered
    # `ActionController::Parameters` instance.
    def transform_keys!(&block)
      return to_enum(:transform_keys!) unless block_given?
      @parameters.transform_keys!(&block)
      self
    end

    # Returns a new `ActionController::Parameters` instance with the results of
    # running `block` once for every key. This includes the keys from the root hash
    # and from all nested hashes and arrays. The values are unchanged.
    def deep_transform_keys(&block)
      new_instance_with_inherited_permitted_status(
        _deep_transform_keys_in_object(@parameters, &block).to_unsafe_h
      )
    end

    # Returns the same `ActionController::Parameters` instance with changed keys.
    # This includes the keys from the root hash and from all nested hashes and
    # arrays. The values are unchanged.
    def deep_transform_keys!(&block)
      @parameters = _deep_transform_keys_in_object(@parameters, &block).to_unsafe_h
      self
    end

    # Deletes a key-value pair from `Parameters` and returns the value. If `key` is
    # not found, returns `nil` (or, with optional code block, yields `key` and
    # returns the result). This method is similar to #extract!, which returns the
    # corresponding `ActionController::Parameters` object.
    def delete(key, &block)
      convert_value_to_parameters(@parameters.delete(key, &block))
    end

    # Returns a new `ActionController::Parameters` instance with only items that the
    # block evaluates to true.
    def select(&block)
      new_instance_with_inherited_permitted_status(@parameters.select(&block))
    end

    # Equivalent to Hash#keep_if, but returns `nil` if no changes were made.
    def select!(&block)
      @parameters.select!(&block)
      self
    end
    alias_method :keep_if, :select!

    # Returns a new `ActionController::Parameters` instance with items that the
    # block evaluates to true removed.
    def reject(&block)
      new_instance_with_inherited_permitted_status(@parameters.reject(&block))
    end

    # Removes items that the block evaluates to true and returns self.
    def reject!(&block)
      @parameters.reject!(&block)
      self
    end
    alias_method :delete_if, :reject!

    # Returns a new `ActionController::Parameters` instance with `nil` values
    # removed.
    def compact
      new_instance_with_inherited_permitted_status(@parameters.compact)
    end

    # Removes all `nil` values in place and returns `self`, or `nil` if no changes
    # were made.
    def compact!
      self if @parameters.compact!
    end

    # Returns a new `ActionController::Parameters` instance without the blank
    # values. Uses Object#blank? for determining if a value is blank.
    def compact_blank
      reject { |_k, v| v.blank? }
    end

    # Removes all blank values in place and returns self. Uses Object#blank? for
    # determining if a value is blank.
    def compact_blank!
      reject! { |_k, v| v.blank? }
    end

    # Returns true if the given value is present for some key in the parameters.
    def has_value?(value)
      each_value.include?(convert_value_to_parameters(value))
    end

    alias value? has_value?

    # Returns values that were assigned to the given `keys`. Note that all the
    # `Hash` objects will be converted to `ActionController::Parameters`.
    def values_at(*keys)
      convert_value_to_parameters(@parameters.values_at(*keys))
    end

    # Returns a new `ActionController::Parameters` instance with all keys from
    # `other_hash` merged into current hash.
    def merge(other_hash)
      new_instance_with_inherited_permitted_status(
        @parameters.merge(other_hash.to_h)
      )
    end

    ##
    # :call-seq: merge!(other_hash)
    #
    # Returns the current `ActionController::Parameters` instance with `other_hash`
    # merged into current hash.
    def merge!(other_hash, &block)
      @parameters.merge!(other_hash.to_h, &block)
      self
    end

    def deep_merge?(other_hash) # :nodoc:
      other_hash.is_a?(ActiveSupport::DeepMergeable)
    end

    # Returns a new `ActionController::Parameters` instance with all keys from
    # current hash merged into `other_hash`.
    def reverse_merge(other_hash)
      new_instance_with_inherited_permitted_status(
        other_hash.to_h.merge(@parameters)
      )
    end
    alias_method :with_defaults, :reverse_merge

    # Returns the current `ActionController::Parameters` instance with current hash
    # merged into `other_hash`.
    def reverse_merge!(other_hash)
      @parameters.merge!(other_hash.to_h) { |key, left, right| left }
      self
    end
    alias_method :with_defaults!, :reverse_merge!

    # This is required by ActiveModel attribute assignment, so that user can pass
    # `Parameters` to a mass assignment methods in a model. It should not matter as
    # we are using `HashWithIndifferentAccess` internally.
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
        # YAML 2.0.9's Hash subclass format where keys and values were stored under an
        # elements hash and `permitted` within an ivars hash.
        @parameters = coder.map["elements"].with_indifferent_access
        @permitted  = coder.map["ivars"][:@permitted]
      when "!ruby/object:ActionController::Parameters"
        # YAML's Object format. Only needed because of the format backwards
        # compatibility above, otherwise equivalent to YAML's initialization.
        @parameters, @permitted = coder.map["parameters"], coder.map["permitted"]
      end
    end

    def encode_with(coder) # :nodoc:
      coder.map = { "parameters" => @parameters, "permitted" => @permitted }
    end

    # Returns a duplicate `ActionController::Parameters` instance with the same
    # permitted parameters.
    def deep_dup
      self.class.new(@parameters.deep_dup, @logging_context).tap do |duplicate|
        duplicate.permitted = @permitted
      end
    end

    # Returns parameter value for the given `key` separated by `delimiter`.
    #
    #     params = ActionController::Parameters.new(id: "1_123", tags: "ruby,rails")
    #     params.extract_value(:id) # => ["1", "123"]
    #     params.extract_value(:tags, delimiter: ",") # => ["ruby", "rails"]
    #     params.extract_value(:non_existent_key) # => nil
    #
    # Note that if the given `key`'s value contains blank elements, then the
    # returned array will include empty strings.
    #
    #     params = ActionController::Parameters.new(tags: "ruby,rails,,web")
    #     params.extract_value(:tags, delimiter: ",") # => ["ruby", "rails", "", "web"]
    def extract_value(key, delimiter: "_")
      @parameters[key]&.split(delimiter, -1)
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

      # Filters self and optionally checks for unpermitted keys
      def permit_filters(filters, on_unpermitted: nil, explicit_arrays: true)
        params = self.class.new

        filters.flatten.each do |filter|
          case filter
          when Symbol, String
            # Declaration [:name, "age"]
            permitted_scalar_filter(params, filter)
          when Hash
            # Declaration [{ person: ... }]
            hash_filter(params, filter, on_unpermitted:, explicit_arrays:)
          end
        end

        unpermitted_parameters!(params, on_unpermitted:)

        params.permit!
      end

    private
      def new_instance_with_inherited_permitted_status(hash)
        self.class.new(hash, @logging_context).tap do |new_instance|
          new_instance.permitted = @permitted
        end
      end

      def convert_parameters_to_hashes(value, using, &block)
        case value
        when Array
          value.map { |v| convert_parameters_to_hashes(v, using) }
        when Hash
          transformed = value.transform_values do |v|
            convert_parameters_to_hashes(v, using)
          end
          (block_given? ? transformed.to_h(&block) : transformed).with_indifferent_access
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
          self.class.new(value, @logging_context)
        else
          value
        end
      end

      def _deep_transform_keys_in_object(object, &block)
        case object
        when Hash
          object.each_with_object(self.class.new) do |(key, value), result|
            result[yield(key)] = _deep_transform_keys_in_object(value, &block)
          end
        when Parameters
          if object.permitted?
            object.to_h.deep_transform_keys(&block)
          else
            object.to_unsafe_h.deep_transform_keys(&block)
          end
        when Array
          object.map { |e| _deep_transform_keys_in_object(e, &block) }
        else
          object
        end
      end

      def _deep_transform_keys_in_object!(object, &block)
        case object
        when Hash
          object.keys.each do |key|
            value = object.delete(key)
            object[yield(key)] = _deep_transform_keys_in_object!(value, &block)
          end
          object
        when Parameters
          if object.permitted?
            object.to_h.deep_transform_keys!(&block)
          else
            object.to_unsafe_h.deep_transform_keys!(&block)
          end
        when Array
          object.map! { |e| _deep_transform_keys_in_object!(e, &block) }
        else
          object
        end
      end

      def specify_numeric_keys?(filter)
        if filter.respond_to?(:keys)
          filter.keys.any? { |key| /\A-?\d+\z/.match?(key) }
        end
      end

      # When an array is expected, you must specify an array explicitly
      # using the following format:
      #
      #     params.expect(comments: [[:flavor]])
      #
      # Which will match only the following array formats:
      #
      #     { pies: [{ flavor: "rhubarb" }, { flavor: "apple" }] }
      #     { pies: { "0" => { flavor: "key lime" }, "1" =>  { flavor: "mince" } } }
      #
      # When using `permit`, arrays are specified the same way as hashes:
      #
      #     params.expect(pies: [:flavor])
      #
      # In this case, `permit` would also allow matching with a hash (or vice versa):
      #
      #     { pies: { flavor: "cherry" } }
      #
      def array_filter?(filter)
        filter.is_a?(Array) && filter.size == 1 && filter.first.is_a?(Array)
      end

      # Called when an explicit array filter is encountered.
      def each_array_element(object, filter, &block)
        case object
        when Array
          object.grep(Parameters).filter_map(&block)
        when Parameters
          if object.nested_attributes? && !specify_numeric_keys?(filter)
            object.each_nested_attribute(&block)
          end
        end
      end

      def unpermitted_parameters!(params, on_unpermitted: self.class.action_on_unpermitted_parameters)
        return unless on_unpermitted
        unpermitted_keys = unpermitted_keys(params)
        if unpermitted_keys.any?
          case on_unpermitted
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
      # This is a list of permitted scalar types that includes the ones supported in
      # XML and JSON requests.
      #
      # This list is in particular used to filter ordinary requests, String goes as
      # first element to quickly short-circuit the common case.
      #
      # If you modify this collection please update the one in the #permit doc as
      # well.
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
      #     puts self.keys #=> ["zipcode(90210i)"]
      #     params = {}
      #
      #     permitted_scalar_filter(params, "zipcode")
      #
      #     puts params.keys # => ["zipcode"]
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

      def non_scalar?(value)
        value.is_a?(Array) || value.is_a?(Parameters)
      end

      EMPTY_ARRAY = [] # :nodoc:
      EMPTY_HASH  = {} # :nodoc:
      def hash_filter(params, filter, on_unpermitted: self.class.action_on_unpermitted_parameters, explicit_arrays: false)
        filter = filter.with_indifferent_access

        # Slicing filters out non-declared keys.
        slice(*filter.keys).each do |key, value|
          next unless value
          next unless has_key? key
          result = permit_value(value, filter[key], on_unpermitted:, explicit_arrays:)
          params[key] = result unless result.nil?
        end
      end

      def permit_value(value, filter, on_unpermitted:,  explicit_arrays:)
        if filter == EMPTY_ARRAY # Declaration { comment_ids: [] }.
          permit_array_of_scalars(value)
        elsif filter == EMPTY_HASH # Declaration { preferences: {} }.
          permit_hash(value, filter, on_unpermitted:, explicit_arrays:)
        elsif array_filter?(filter) # Declaration { comments: [[:text]] }
          permit_array_of_hashes(value, filter.first, on_unpermitted:, explicit_arrays:)
        elsif explicit_arrays # Declaration { user: { address: ... } } or { user: [:name, ...] } (only allows hash value)
          permit_hash(value, filter, on_unpermitted:, explicit_arrays:)
        elsif non_scalar?(value) # Declaration { user: { address: ... } } or { user: [:name, ...] }
          permit_hash_or_array(value, filter, on_unpermitted:, explicit_arrays:)
        end
      end

      def permit_array_of_scalars(value)
        value if value.is_a?(Array) && value.all? { |element| permitted_scalar?(element) }
      end

      def permit_array_of_hashes(value, filter, on_unpermitted:, explicit_arrays:)
        each_array_element(value, filter) do |element|
          element.permit_filters(Array.wrap(filter), on_unpermitted:, explicit_arrays:)
        end
      end

      def permit_hash(value, filter, on_unpermitted:, explicit_arrays:)
        return unless value.is_a?(Parameters)

        if filter == EMPTY_HASH
          permit_any_in_parameters(value)
        else
          value.permit_filters(Array.wrap(filter), on_unpermitted:, explicit_arrays:)
        end
      end

      def permit_hash_or_array(value, filter, on_unpermitted:, explicit_arrays:)
        permit_array_of_hashes(value, filter, on_unpermitted:, explicit_arrays:) ||
          permit_hash(value, filter, on_unpermitted:, explicit_arrays:)
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
            when Array
              sanitized << permit_any_in_array(element)
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

  # # Strong Parameters
  #
  # It provides an interface for protecting attributes from end-user assignment.
  # This makes Action Controller parameters forbidden to be used in Active Model
  # mass assignment until they have been explicitly enumerated.
  #
  # In addition, parameters can be marked as required and flow through a
  # predefined raise/rescue flow to end up as a `400 Bad Request` with no effort.
  #
  #     class PeopleController < ActionController::Base
  #       # Using "Person.create(params[:person])" would raise an
  #       # ActiveModel::ForbiddenAttributesError exception because it'd
  #       # be using mass assignment without an explicit permit step.
  #       # This is the recommended form:
  #       def create
  #         Person.create(person_params)
  #       end
  #
  #       # This will pass with flying colors as long as there's a person key in the
  #       # parameters, otherwise it'll raise an ActionController::ParameterMissing
  #       # exception, which will get caught by ActionController::Base and turned
  #       # into a 400 Bad Request reply.
  #       def update
  #         redirect_to current_account.people.find(params[:id]).tap { |person|
  #           person.update!(person_params)
  #         }
  #       end
  #
  #       private
  #         # Using a private method to encapsulate the permissible parameters is
  #         # a good pattern since you'll be able to reuse the same permit
  #         # list between create and update. Also, you can specialize this method
  #         # with per-user checking of permissible attributes.
  #         def person_params
  #           params.expect(person: [:name, :age])
  #         end
  #     end
  #
  # In order to use `accepts_nested_attributes_for` with Strong Parameters, you
  # will need to specify which nested attributes should be permitted. You might
  # want to allow `:id` and `:_destroy`, see ActiveRecord::NestedAttributes for
  # more information.
  #
  #     class Person
  #       has_many :pets
  #       accepts_nested_attributes_for :pets
  #     end
  #
  #     class PeopleController < ActionController::Base
  #       def create
  #         Person.create(person_params)
  #       end
  #
  #       ...
  #
  #       private
  #
  #         def person_params
  #           # It's mandatory to specify the nested attributes that should be permitted.
  #           # If you use `permit` with just the key that points to the nested attributes hash,
  #           # it will return an empty hash.
  #           params.expect(person: [ :name, :age, pets_attributes: [ :id, :name, :category ] ])
  #         end
  #     end
  #
  # See ActionController::Parameters.expect,
  # See ActionController::Parameters.require, and
  # ActionController::Parameters.permit for more information.
  module StrongParameters
    # Returns a new ActionController::Parameters object that has been instantiated
    # with the `request.parameters`.
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

    # Assigns the given `value` to the `params` hash. If `value` is a Hash, this
    # will create an ActionController::Parameters object that has been instantiated
    # with the given `value` hash.
    def params=(value)
      @_params = value.is_a?(Hash) ? Parameters.new(value) : value
    end
  end
end
