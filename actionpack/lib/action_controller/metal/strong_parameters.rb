require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/rescuable'

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
  #   Person.first.update_attributes!(permitted)
  #   # => #<Person id: 1, name: "Francesco", age: 22, role: "user">
  #
  # It provides a +permit_all_parameters+ option that controls the top-level
  # behaviour of new instances. If it's +true+, all the parameters will be
  # permitted by default. The default value for +permit_all_parameters+
  # option is +false+.
  #
  #   params = ActionController::Parameters.new
  #   params.permitted? # => false
  #
  #   ActionController::Parameters.permit_all_parameters = true
  #
  #   params = ActionController::Parameters.new
  #   params.permitted? # => true
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
    #   permitted = params.permit(person: [ :name, { pets: :name } ])
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
        when Symbol, String then
          if has_key?(filter)
            _value = self[filter]
            params[filter] = _value unless Hash === _value
          end
          keys.grep(/\A#{Regexp.escape(filter)}\(\d+[if]?\)\z/) { |key| params[key] = self[key] }
        when Hash then
          filter = filter.with_indifferent_access

          self.slice(*filter.keys).each do |key, values|
            return unless values

            key = key.to_sym

            params[key] = each_element(values) do |value|
              # filters are a Hash, so we expect value to be a Hash too
              next if filter.is_a?(Hash) && !value.is_a?(Hash)

              value = self.class.new(value) if !value.respond_to?(:permit)

              value.permit(*Array.wrap(filter[key]))
            end
          end
        end
      end

      params.permit!
    end

    # Returns a parameter for the given +key+. If not found,
    # returns +nil+.
    #
    #   params = ActionController::Parameters.new(person: { name: 'Francesco' })
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
  #         person.update_attributes!(person_params)
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

    included do
      rescue_from(ActionController::ParameterMissing) do |parameter_missing_exception|
        render text: "Required parameter missing: #{parameter_missing_exception.param}", status: :bad_request
      end
    end

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
