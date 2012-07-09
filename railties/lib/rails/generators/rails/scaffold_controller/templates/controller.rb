<% if namespaced? -%>
require_dependency "<%= namespaced_file_path %>/application_controller"

<% end -%>
<% module_namespacing do -%>
class <%= controller_class_name %>Controller < ApplicationController
  respond_to :html, :json

  # GET <%= route_url %>
  # GET <%= route_url %>.json
  def index
    @<%= plural_table_name %> = <%= orm_class.all(class_name) %>

    respond_with(@<%= plural_table_name %>)
  end

  # GET <%= route_url %>/1
  # GET <%= route_url %>/1.json
  def show
    @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>

    respond_with(@<%= singular_table_name %>)
  end

  # GET <%= route_url %>/new
  # GET <%= route_url %>/new.json
  def new
    @<%= singular_table_name %> = <%= orm_class.build(class_name) %>

    respond_with(@<%= singular_table_name %>)
  end

  # GET <%= route_url %>/1/edit
  def edit
    @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>

    respond_with(@<%= singular_table_name %>)
  end

  # POST <%= route_url %>
  # POST <%= route_url %>.json
  def create
    @<%= singular_table_name %> = <%= orm_class.build(class_name, "params[:#{singular_table_name}]") %>
    flash[:notice] = <%= "'#{human_name} was successfully created.'" %> if @<%= orm_instance.save %>

    respond_with(@<%= singular_table_name %>)
  end

  # PATCH/PUT <%= route_url %>/1
  # PATCH/PUT <%= route_url %>/1.json
  def update
    @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>
    flash[:notice] = <%= "'#{human_name} was successfully updated.'" %> if @<%= orm_instance.update_attributes("params[:#{singular_table_name}]") %>

    respond_with(@<%= singular_table_name %>)
  end

  # DELETE <%= route_url %>/1
  # DELETE <%= route_url %>/1.json
  def destroy
    @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>
    @<%= orm_instance.destroy %>

    respond_with(@<%= singular_table_name %>)
  end
end
<% end -%>
