module ActionController
  module Scaffolding # :nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Scaffolding is a way to quickly put an Active Record class online by providing a series of standardized actions
    # for listing, showing, creating, updating, and destroying objects of the class. These standardized actions come
    # with both controller logic and default templates that through introspection already know which fields to display
    # and which input types to use. Example:
    #
    #  class WeblogController < ActionController::Base
    #    scaffold :entry
    #  end
    #
    # This tiny piece of code will add all of the following methods to the controller:
    #
    #  class WeblogController < ActionController::Base
    #    verify :method => :post, :only => [ :destroy, :create, :update ],
    #           :redirect_to => { :action => :list }
    #
    #    def index
    #      list
    #    end
    #
    #    def list
    #      @entries = Entry.find(:all)
    #      render_scaffold "list"
    #    end
    #
    #    def show
    #      @entry = Entry.find(params[:id])
    #      render_scaffold
    #    end
    #
    #    def destroy
    #      Entry.find(params[:id]).destroy
    #      redirect_to :action => "list"
    #    end
    #
    #    def new
    #      @entry = Entry.new
    #      render_scaffold
    #    end
    #
    #    def create
    #      @entry = Entry.new(params[:entry])
    #      if @entry.save
    #        flash[:notice] = "Entry was successfully created"
    #        redirect_to :action => "list"
    #      else
    #        render_scaffold('new')
    #      end
    #    end
    #
    #    def edit
    #      @entry = Entry.find(params[:id])
    #      render_scaffold
    #    end
    #
    #    def update
    #      @entry = Entry.find(params[:id])
    #      @entry.attributes = params[:entry]
    #
    #      if @entry.save
    #        flash[:notice] = "Entry was successfully updated"
    #        redirect_to :action => "show", :id => @entry
    #      else
    #        render_scaffold('edit')
    #      end
    #    end
    #  end
    #
    # The <tt>render_scaffold</tt> method will first check to see if you've made your own template (like "weblog/show.rhtml" for
    # the show action) and if not, then render the generic template for that action. This gives you the possibility of using the
    # scaffold while you're building your specific application. Start out with a totally generic setup, then replace one template
    # and one action at a time while relying on the rest of the scaffolded templates and actions.
    module ClassMethods
      # Adds a swath of generic CRUD actions to the controller. The +model_id+ is automatically converted into a class name unless
      # one is specifically provide through <tt>options[:class_name]</tt>. So <tt>scaffold :post</tt> would use Post as the class
      # and @post/@posts for the instance variables.
      #
      # It's possible to use more than one scaffold in a single controller by specifying <tt>options[:suffix] = true</tt>. This will
      # make <tt>scaffold :post, :suffix => true</tt> use method names like list_post, show_post, and create_post
      # instead of just list, show, and post. If suffix is used, then no index method is added.
      def scaffold(model_id, options = {})
        options.assert_valid_keys(:class_name, :suffix)

        singular_name = model_id.to_s
        class_name    = options[:class_name] || singular_name.camelize
        plural_name   = singular_name.pluralize
        suffix        = options[:suffix] ? "_#{singular_name}" : ""

        unless options[:suffix]
          module_eval <<-"end_eval", __FILE__, __LINE__
            def index
              list
            end
          end_eval
        end

        module_eval <<-"end_eval", __FILE__, __LINE__

          verify :method => :post, :only => [ :destroy#{suffix}, :create#{suffix}, :update#{suffix} ],
                 :redirect_to => { :action => :list#{suffix} }


          def list#{suffix}
            @#{singular_name}_pages, @#{plural_name} = paginate :#{plural_name}, :per_page => 10
            render#{suffix}_scaffold "list#{suffix}"
          end

          def show#{suffix}
            @#{singular_name} = #{class_name}.find(params[:id])
            render#{suffix}_scaffold
          end

          def destroy#{suffix}
            #{class_name}.find(params[:id]).destroy
            redirect_to :action => "list#{suffix}"
          end

          def new#{suffix}
            @#{singular_name} = #{class_name}.new
            render#{suffix}_scaffold
          end

          def create#{suffix}
            @#{singular_name} = #{class_name}.new(params[:#{singular_name}])
            if @#{singular_name}.save
              flash[:notice] = "#{class_name} was successfully created"
              redirect_to :action => "list#{suffix}"
            else
              render#{suffix}_scaffold('new')
            end
          end

          def edit#{suffix}
            @#{singular_name} = #{class_name}.find(params[:id])
            render#{suffix}_scaffold
          end

          def update#{suffix}
            @#{singular_name} = #{class_name}.find(params[:id])
            @#{singular_name}.attributes = params[:#{singular_name}]

            if @#{singular_name}.save
              flash[:notice] = "#{class_name} was successfully updated"
              redirect_to :action => "show#{suffix}", :id => @#{singular_name}
            else
              render#{suffix}_scaffold('edit')
            end
          end

          private
            def render#{suffix}_scaffold(action=nil)
              action ||= caller_method_name(caller)
              # logger.info ("testing template:" + "\#{self.class.controller_path}/\#{action}") if logger

              if template_exists?("\#{self.class.controller_path}/\#{action}")
                render :action => action
              else
                @scaffold_class = #{class_name}
                @scaffold_singular_name, @scaffold_plural_name = "#{singular_name}", "#{plural_name}"
                @scaffold_suffix = "#{suffix}"
                add_instance_variables_to_assigns

                @template.instance_variable_set("@content_for_layout", @template.render_file(scaffold_path(action.sub(/#{suffix}$/, "")), false))

                if !active_layout.nil?
                  render :file => active_layout, :use_full_path => true
                else
                  render :file => scaffold_path('layout')
                end
              end
            end

            def scaffold_path(template_name)
              File.dirname(__FILE__) + "/templates/scaffolds/" + template_name + ".rhtml"
            end

            def caller_method_name(caller)
              caller.first.scan(/`(.*)'/).first.first # ' ruby-mode
            end
        end_eval
      end
    end
  end
end
