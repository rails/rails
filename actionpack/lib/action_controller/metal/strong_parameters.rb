require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/array/wrap'
require 'active_support/rescuable'
require 'action_dispatch/http/upload'

module ActionController
  # Raised when a required parameter is missing.
  #
  #   params = ActionController::Parameters.new(a: {})
  #   params.fetch(:b)
  #   # => ActionController::ParameterMissing: param not found: b
  #   params.require(:a)
  #   # => ActionController::ParameterMissing: param not found: a
  class ParameterMissing < KeyError
    attr_reader :param # :nodoc:

    def initialize(param) # :nodoc:
      @param = param
      super("param not found: #{param}")
    end
  end

  # Raised when a supplied parameter is not expected.
  #
  #   params = ActionController::Parameters.new(a: "123", b: "456")
  #   params.permit(:c)
  #   # => ActionController::UnpermittedParameters: found unexpected keys: a, b
  class UnpermittedParameters < IndexError
    attr_reader :params # :nodoc:

    def initialize(params) # :nodoc:
      @params = params
      super("found unpermitted parameters: #{params.join(", ")}")
    end
  end

  # == Action Controller \Parameters
  #
  # Allows to choose which attributes should be whitelisted for mass updating
  # and thus prevent accidentally exposing that which shouldn’t be exposed.
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
  # <tt>ActionController::Parameters</tt> is inherited from
  # <tt>ActiveSupport::HashWithIndifferentAccess</tt>, this means
  # that you can fetch values using either <tt>:key</tt> or <tt>"key"</tt>.
  #
  #   params = ActionController::Parameters.new(key: 'value')
  #   params[:key]  # => "value"
  #   params["key"] # => "value"
  class Parameters < ActiveSupport::HashWithIndifferentAccess
    cattr_accessor :permit_all_parameters, instance_accessor: false
    cattr_accessor :action_on_unpermitted_parameters, instance_accessor: false

    # Never raise an UnpermittedParameters exception because of these params
    # are present. They are added by Rails and it's of no concern.
    NEVER_UNPERMITTED_PARAMS = %w( controller action )

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
    def initialize(attributes = nil)
      super(attributes)
      @permitted = self.class.permit_all_parameters
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
        convert_hashes_to_parameters(key, value)
        self[key].permit! if self[key].respond_to? :permit!
      end

      @permitted = true
      self
    end

    # Ensures that a parameter is present. If it's present, returns
    # the parameter at the given +key+, otherwise raises an
    # <tt>ActionController::ParameterMissing</tt> error.
    #
    #   ActionController::Parameters.new(person: { name: 'Francesco' }).require(:person)
    #   # => {"name"=>"Francesco"}
    #
    #   ActionController::Parameters.new(person: nil).require(:person)
    #   # => ActionController::ParameterMissing: param not found: person
    #
    #   ActionController::Parameters.new(person: {}).require(:person)
    #   # => ActionController::ParameterMissing: param not found: person
    def require(key)
      self[key].presence || raise(ParameterMissing.new(key))
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
    # +:name+ passes it is a key of +params+ whose associated value is of type
    # +String+, +Symbol+, +NilClass+, +Numeric+, +TrueClass+, +FalseClass+,
    # +Date+, +Time+, +DateTime+, +StringIO+, +IO+,
    # +ActionDispatch::Http::UploadedFile+ or +Rack::Test::UploadedFile+.
    # Otherwise, the key +:name+ is filtered out.
    #
    # You may declare that the parameter should be an array of permitted scalars
    # by mapping it to an empty array:
    #
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
    #         email: 'none@test.com'
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
      convert_hashes_to_parameters(key, super)
    end

    # Returns a parameter for the given +key+. If the +key+
    # can't be found, there are several options: With no other arguments,
    # it will raise an <tt>ActionController::ParameterMissing</tt> error;
    # if more arguments are given, then that will be returned; if a block
    # is given, then that will be run and its result returned.
    #
    #   params = ActionController::Parameters.new(person: { name: 'Francesco' })
    #   params.fetch(:person)               # => {"name"=>"Francesco"}
    #   params.fetch(:none)                 # => ActionController::ParameterMissing: param not found: none
    #   params.fetch(:none, 'Francesco')    # => "Francesco"
    #   params.fetch(:none) { 'Francesco' } # => "Francesco"
    def fetch(key, *args)
      convert_hashes_to_parameters(key, super)
    rescue KeyError
      raise ActionController::ParameterMissing.new(key)
    end

    # Returns a new <tt>ActionController::Parameters</tt> instance that
    # includes only the given +keys+. If the given +keys+
    # don't exist, returns an empty hash.
    #
    #   params = ActionController::Parameters.new(a: 1, b: 2, c: 3)
    #   params.slice(:a, :b) # => {"a"=>1, "b"=>2}
    #   params.slice(:d)     # => {}
    def slice(*keys)
      self.class.new(super).tap do |new_instance|
        new_instance.instance_variable_set :@permitted, @permitted
      end
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
        duplicate.instance_variable_set :@permitted, @permitted
      end
    end

    private
      def convert_hashes_to_parameters(key, value)
        if value.is_a?(Parameters) || !value.is_a?(Hash)
          value
        else
          # Convert to Parameters on first access
          self[key] = self.class.new(value)
        end
      end

      def each_element(object)
        if object.is_a?(Array)
          object.map { |el| yield el }.compact
        elsif object.is_a?(Hash) && object.keys.all? { |k| k =~ /\A-?\d+\z/ }
          hash = object.class.new
          object.each { |k,v| hash[k] = yield v }
          hash
        else
          yield object
        end
      end

      def unpermitted_parameters!(params)
        unpermitted_keys = unpermitted_keys(params)
        if unpermitted_keys.any?
          case self.class.action_on_unpermitted_parameters
          when :log
            ActionController::Base.logger.debug "Unpermitted parameters: #{unpermitted_keys.join(", ")}"
          when :raise
            raise ActionController::UnpermittedParameters.new(unpermitted_keys)
          end
        end
      end

      def unpermitted_keys(params)
        self.keys - params.keys - NEVER_UNPERMITTED_PARAMS
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
        if value.is_a?(Array)
          value.all? {|element| permitted_scalar?(element)}
        end
      end

      def array_of_permitted_scalars_filter(params, key)
        if has_key?(key) && array_of_permitted_scalars?(self[key])
          params[key] = self[key]
        end
      end

      EMPTY_ARRAY = []
      def hash_filter(params, filter)
        filter = filter.with_indifferent_access

        # Slicing filters out non-declared keys.
        slice(*filter.keys).each do |key, value|
          return unless value

          if filter[key] == EMPTY_ARRAY
            # Declaration { comment_ids: [] }.
            array_of_permitted_scalars_filter(params, key)
          else
            # Declaration { user: :name } or { user: [:name, :age, { adress: ... }] }.
            params[key] = each_element(value) do |element|
              if element.is_a?(Hash)
                element = self.class.new(element) unless element.respond_to?(:permit)
                element.permit(*Array.wrap(filter[key]))
              end
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
  #     # ActiveModel::ForbiddenAttributes exception because it'd
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
  # In order to use <tt>accepts_nested_attribute_for</tt> with Strong \Parameters, you
  # will need to specify which nested attributes should be whitelisted.
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
  #         params.require(:person).permit(:name, :age, pets_attributes: [ :name, :category ])
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
