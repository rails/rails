require 'active_resource/associations/association_collection'

module ActiveResource
  module Associations

    # Active Resource Associations works in the same way than Active Record
    # associations, it follows the same coventions and method names.
    # At the moment it support only one-to-one and one-to-many associations,
    # many-to-many associations are not implemented yet.
    #
    # An example of use:
    #
    #   class Project < ActiveRecord::Base
    #     self.site = "http://37s.sunrise.i:3000"
    #
    #     belongs_to              :portfolio
    #     has_one                 :project_manager
    #     has_many                :milestones
    #   end
    #
    # The project class now has the following methods in order to manipulate the relationships:
    # * <tt>Project#portfolio, Project#portfolio=(portfolio), Project#portfolio.nil?</tt>
    # * <tt>Project#project_manager, Project#project_manager=(project_manager), Project#project_manager.nil?,</tt>
    # * <tt>Project#milestones.empty?, Project#milestones.size, Project#milestones, Project#milestones<<(milestone), Project#milestone.delete(milestone)</tt>
    #
    #
    # == Auto-generated methods
    #
    # === Singular associations (one-to-one)
    #                                     |            |  belongs_to  |
    #   generated methods                 | belongs_to | :polymorphic | has_one
    #   ----------------------------------+------------+--------------+---------
    #   other                             |     X      |      X       |    X
    #   other=(other)                     |     X      |      X       |    X
    #
    # ===Collection associations (one-to-many)
    #
    #   generated methods (only one-to-many)
    #   --------------------------
    #   others
    #   others=[other,other]
    #   others<<
    #   others.size
    #   others.length
    #   others.count
    #   others.empty?
    #   others.clear
    #   others.delete(other)
    #
    #
    # === One-to-one
    #
    #  Use has_one in the base, and belongs_to in the associated model.
    #
    #   class ProjectManager < ActiveResource::Base
    #     self.site = "http://37s.sunrise.i:3000"
    #     belongs_to :project
    #   end
    #
    #   class Project < ActiveResource::Base
    #     self.site = "http://37s.sunrise.i:3000"
    #     has_one :project_manager
    #   end
    #
    #   @project = Project.find(1)
    #   @project.project_manager = ProjectManager.find(3)
    #   @project.project_manager #=> #<ProjectManager:0x7fb91bb05708 @persisted=true,
    #            @attributes={"name"=>"David", "project_id"=>1, "id"=>5}, @prefix_options={}>
    #
    #
    # === One-to-many
    #
    # Use has_many in the base, and belongs_to in the associated model.
    #
    #   class Project < ActiveResource::Base
    #     self.site = "http://37s.sunrise.i:3000"
    #     has_many :milestones
    #   end
    #
    #   class Milestone < ActiveResource::Base
    #     self.site = "http://37s.sunrise.i:3000"
    #   end
    #
    #   @milestone = Milestone.find(2)
    #   @project   = Project.find(1)
    #   @project.milestones << @milestone
    #
    #   This will set the @milestone.milestone_id to @project.id
    #   and save @milestone, then when you call @project.milestones
    #   will return an AssociationCollection list with the recently milestone added
    #   included.
    #
    #   @project.milestones #=>[#<Milestone:0x7f8b3134ac88 @persisted=true,
    #                    @attributes={"title"=>"pre", "project_id"=>nil, "id"=>1},
    #                    @prefix_options={}>, #<Milestone:0x7f8b31324768 @errors=#<OrderedHash {}>,
    #                    @validation_context=nil, @persisted=true, @attributes={"title"=>"rc other",
    #                    "project_id"=>nil, "id"=>2}, @remote_errors=nil, @prefix_options={}>]
    #
    #
    # === Collections
    #
    # * Adding an object to a collection (+has_many+) automatically saves that resource.
    #
    # === Cache
    #
    # * Every association set an instance variable over the base resource and works
    #   with a simple cache that keep the result of the last fetched resource
    #   unless you specifically instructed not to.
    #
    #    project.milestones             # fetches milestones resources
    #    project.milestones.size        # uses the milestone cache
    #    project.milestones.empty?      # uses the milestone cache
    #    project.milestones(true).size  # fetches milestones from the database
    #    project.milestones             # uses the milestone cache
    #
    def self.included(klass)
      klass.send :include, InstanceMethods
      klass.extend ClassMethods
    end

    module InstanceMethods
      def set_resource_instance_variable(resource, force_reload = false)
        if !instance_variable_defined?("@#{resource}") or force_reload
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

      def has_one(resource, opts = {})
        o  = options(:has_one, resource)

        # Define accessor method for resource
        #
        define_method(resource) do |*force_reload|
          force_reload = force_reload.first || false

          set_resource_instance_variable(resource, force_reload) do
            o[:klass].constantize.find(:first, :params => { o[:association_col] => id })
          end
        end

        # Define writter method for resource
        #
        define_method("#{resource}=") do |new_resource|
          if send(resource).blank?
            new_resource.send("#{o[:association_col]}=", id)
            instance_variable_set("@#{resource}", new_resource.save)
          else
            instance_variable_get("@#{resource}").send(:update_attribute, o[:association_col], id)
          end
        end
      end

      def belongs_to(resource, opts = {})
        o  = options(:belongs_to, resource)

        # Define accessor method for resource
        #
        define_method(resource) do |*force_reload|
          force_reload = force_reload.first || false

          association_col = send o[:association_col]
          return nil if association_col.nil?
          set_resource_instance_variable(resource, force_reload){
            o[:klass].constantize.find(association_col)
          }
        end

        # Define writter method for resource
        #
        define_method("#{resource}=") do |new_resource|
          if send(o[:association_col]) != new_resource.id
            send "#{o[:association_col]}=", new_resource.id
          end
          instance_variable_set("@#{resource}", new_resource)
        end
      end

      def has_many(resource, opts = {})
        o  = options(:has_many, resource)

        # Define accessor method for resource
        #
        define_method(resource) do |*force_reload|
          force_reload = force_reload.first || false

          set_resource_instance_variable(resource, force_reload) {
            result = o[:klass].constantize.find(:all,
                     :params => { o[:association_col] => id }) || []

             AssociationCollection.new result, self, o[:association_col]
          }
        end

        define_method("#{resource}=") do |new_collection|
          collection = send(resource)
          to_remove  = collection - new_collection
          to_remove.each{|m| collection.delete(m)}

          # FIXME should call the old clear
          collection.clear
          # FIXME Is this needed?
          collection.concat new_collection
        end
      end

    end
  end

end
