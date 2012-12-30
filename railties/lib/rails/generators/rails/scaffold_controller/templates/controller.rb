<% if namespaced? -%>
require_dependency "<%= namespaced_file_path %>/application_controller"

<% end -%>
<% module_namespacing do -%>
class <%= controller_class_name %>Controller < ApplicationController
  before_action :set_<%= singular_table_name %>, only: [:show, :edit, :update, :destroy]
  <%- if options[:html] -%>
    respond_to :html, :json
  <%- else -%>
    respond_to :json
  <%- end -%>
  

  # GET <%= route_url %>
  # GET <%= route_url %>.json
  def index
    @<%= plural_table_name %> = <%= orm_class.all(class_name) %>
    respond_with @<%= plural_table_name %>
  end

  # GET <%= route_url %>/1
  # GET <%= route_url %>/1.json
  def show
    respond_with @<%= singular_table_name %> 
  end

  <%- if options[:html] -%>
  # GET <%= route_url %>/new
  # GET <%= route_url %>/new.json
  def new
    @<%= singular_table_name %> = <%= orm_class.build(class_name) %>
    respond_with @<%= singular_table_name %>
  end

  # GET <%= route_url %>/1/edit
  def edit
  end
  <%- end -%>

  # POST <%= route_url %>
  # POST <%= route_url %>.json
  def create
    @<%= singular_table_name %> = <%= orm_class.build(class_name, "#{singular_table_name}_params") %>
    if @<%= orm_instance.save %>
      flash[:notice] = <%= "'#{human_name} was successfully created.'" %>
    end
    respond_with @<%= singular_table_name %>
  end

  # PATCH/PUT <%= route_url %>/1
  # PATCH/PUT <%= route_url %>/1.json
  def update
    if @<%= orm_instance.update_attributes("#{singular_table_name}_params") %>
      flash[:notice] = <%= "'#{human_name} was successfully updated.'" %>
    end
    respond_with @<%= singular_table_name %>
  end

  # DELETE <%= route_url %>/1
  # DELETE <%= route_url %>/1.json
  def destroy
    @<%= orm_instance.destroy %>
    respond_with @<%= singular_table_name %> do |format|
      <%- if options[:html] -%>
      format.html { redirect_to <%= index_helper %>_url }
      <%- end -%>
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_<%= singular_table_name %>
      @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>
    end

    # Use this method to whitelist the permissible parameters. Example:
    #   params.require(:person).permit(:name, :age)
    #
    # Also, you can specialize this method with per-user checking of permissible
    # attributes.
    def <%= "#{singular_table_name}_params" %>
      <%- if attributes_names.empty? -%>
      params[<%= ":#{singular_table_name}" %>]
      <%- else -%>
      params.require(<%= ":#{singular_table_name}" %>).permit(<%= attributes_names.map { |name| ":#{name}" }.join(', ') %>)
      <%- end -%>
    end
end
<% end -%>
