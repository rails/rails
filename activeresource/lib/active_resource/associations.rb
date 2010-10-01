module ActiveResource
  module Associations

    def self.included(klass)
      klass.send :include, InstanceMethods
      klass.extend ClassMethods
    end

    module InstanceMethods
      def set_resource_instance_variable(resource, default_value = nil)
        if !instance_variable_defined?("@#{resource}") ||
            instance_variable_get("@#{resource}").blank?
          instance_variable_set("@#{resource}", yield)
        end
        instance_variable_get("@#{resource}")
      end
    end

    module ClassMethods

      def options(association, resource)
        o = { :klass => klass_for(association, resource) }
        o[:host_klass] = self

        case association
        when :has_many
          o[:association_col] = o[:host_klass].to_s.singularize
        when :belongs_to
          o[:association_col] = o[:klass]
        when :has_one
          o[:association_col] = o[:host_klass].to_s
        end
        o[:association_col] = "#{o[:association_col].underscore}_id".to_sym
        o
      end

      def klass_for(association, resource)
        resource = resource.to_s
        resource = resource.singularize if association == :has_many
        resource.camelize
      end

      #######################################################################
      # has_one association
      #

      def has_one(resource, opts = {})
        o  = options(:has_one, resource)

        #----------------------------------------------------------------------#
        #   Define accessor method for resource
        #
        #----------------------------------------------------------------------#
        define_method(resource) do
          set_resource_instance_variable(resource) do
            o[:klass].constantize.find(:first, :params => { o[:association_col] => id })
          end
        end

        #----------------------------------------------------------------------#
        # Define writter method for resource
        #
        #----------------------------------------------------------------------#
        define_method("#{resource}=") do |new_resource|
          if send(resource).blank?
            new_resource.send("#{o[:association_col]}=", id)
            instance_variable_set("@#{resource}", new_resource.save)
          else
            instance_variable_get("@#{resource}").send(:update_attribute, o[:association_col], id)
          end
        end
      end

      #######################################################################
      # belongs_to association
      #

      def belongs_to(resource, opts = {})
        o  = options(:belongs_to, resource)

        #----------------------------------------------------------------------#
        #   Define accessor method for resource
        #
        #----------------------------------------------------------------------#
        define_method(resource) do
          association_col = send o[:association_col]
          return nil if association_col.nil?
          set_resource_instance_variable(resource){ o[:klass].constantize.find(association_col) }
        end

        #----------------------------------------------------------------------#
        # Define writter method for resource
        #
        #----------------------------------------------------------------------#
        define_method("#{resource}=") do |new_resource|
          if send(o[:association_col]) != new_resource.id
            send "#{o[:association_col]}=", new_resource.id
          end
          instance_variable_set("@#{resource}", new_resource)
        end
      end

      #######################################################################
      # has_many association
      #

      def has_many(resource, opts = {})
        o  = options(:has_many, resource)

        #----------------------------------------------------------------------#
        #   Define accessor method for resource
        #
        #----------------------------------------------------------------------#
        define_method(resource) do
          collection = o[:klass].constantize.find(:all,
                       :params => { o[:association_col] => id })

          eval "
          def collection.<<(member)
            member.send(:#{o[:association_col]}=, #{id})
            member.save
          end"

          set_resource_instance_variable(resource) do
            collection
          end
        end
      end

    end
  end

end
