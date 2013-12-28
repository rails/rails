<% if namespaced? -%>
require_dependency "<%= namespaced_file_path %>/application_controller"

<% end -%>
<% module_namespacing do -%>
class <%= controller_class_name %>Controller < ApplicationController
  before_action :set_<%= singular_table_name %>, only: [:show, :edit, :update, :destroy]
  
  <%- if collection_routing? -%>
  # GET <%= route_url %>/1..10,17
  def index
    @<%= plural_table_name %> = <%= singular_table_name %>_ids ? <%= orm_class.find(class_name, "#{singular_table_name}_ids") %> : <%= orm_class.all(class_name) %>
  end

  # <%= singular_table_name.capitalize %> ids
  def <%= singular_table_name %>_ids
    @<%= plural_table_name %>_ids ||= params.permit(ids: 1..2**32-1)
  end
  <%- else -%>
  # GET <%= route_url %>
  def index
    @<%= plural_table_name %> = <%= orm_class.all(class_name) %>
  end
  <%- end -%>

  # GET <%= route_url %>/1
  def show
  end

  # GET <%= route_url %>/new
  def new
    @<%= singular_table_name %> = <%= orm_class.build(class_name) %>
  end

  # GET <%= route_url %>/1/edit
  def edit
  end

  # POST <%= route_url %>
  <%- if collection_routing? -%>
  def create
    <%= plural_table_name %>_params ? create_many : create_one
  end

  def create_many
    @<%= plural_table_name %> = <%= class_name %>.create(<%= plural_table_name %>_params)
    redirect_to <%= plural_table_name %>_url(@<%= plural_table_name %>), notice: <%= "'#{human_name}s were successfully updated.'" %>
  end

  def create_one
    @<%= singular_table_name %> = <%= class_name %>.create(<%= singular_table_name %>_params)
    redirect_to <%= singular_table_name %>_url(@<%= singular_table_name %>), notice: <%= "'#{human_name} was successfully updated.'" %>
  end
  <%- else -%>
  def create
    @<%= singular_table_name %> = <%= orm_class.build(class_name, "#{singular_table_name}_params") %>

    if @<%= orm_instance.save %>
      redirect_to @<%= singular_table_name %>, notice: <%= "'#{human_name} was successfully created.'" %>
    else
      render action: 'new'
    end
  end
  <%- end -%>

  # PATCH/PUT <%= route_url %>/1
  def update
    if @<%= orm_instance.update("#{singular_table_name}_params") %>
      redirect_to @<%= singular_table_name %>, notice: <%= "'#{human_name} was successfully updated.'" %>
    else
      render action: 'edit'
    end
  end

  # DELETE <%= route_url %>/1
  def destroy
    @<%= orm_instance.destroy %>
    redirect_to <%= index_helper %>_url, notice: <%= "'#{human_name} was successfully destroyed.'" %>
  end
  <% if collection_routing? %>
  # Collection routes
  # PATCH <%= route_url %>/1..10
  def update_many
    <%= orm_class.find(class_name, "#{singular_table_name}_ids") %>.each do |<%= singular_table_name %>|
      <%= singular_table_name %>.update(params[:<%= plural_table_name %>][:"#{<%= singular_table_name %>.id}"])
    end
    redirect_to @<%= singular_table_name %>, notice: <%= "'#{human_name}s were successfully updated.'" %>
  end

  # PUT <%= route_url %>/1..10
  def replace
    <%= orm_class.destroy_all(class_name) %>
    create
  end

  # DELETE /users/1..10
  def destroy_many
    @<%= plural_table_name %> = <%= orm_class.destroy(class_name, "#{plural_table_name}_ids") %>
  end
  <% end %>
  private
    # Use callbacks to share common setup or constraints between actions.
    def set_<%= singular_table_name %>
      @<%= singular_table_name %> = <%= orm_class.find(class_name, "params[:id]") %>
    end

    # Only allow a trusted parameter "white list" through.
    def <%= "#{singular_table_name}_params" %>
      <%- if attributes_names.empty? -%>
      params[:<%= singular_table_name %>]
      <%- else -%>
      params.require(:<%= singular_table_name %>).permit(<%= attributes_names.map { |name| ":#{name}" }.join(', ') %>)
      <%- end -%>
    end
    <%- if collection_routing? -%>
    
    # Only allow a trusted collection parameter "white list" through.
    def <%= "#{plural_table_name}_params" %>
      <%- if attributes_names.empty? -%>
      params[<%= ":#{plural_table_name}" %>]
      <%- else -%>
      params.require(<%= ":#{plural_table_name}" %>).permit(<%= attributes_names.map { |name| ":#{name}" }.join(', ') %>)
      <%- end -%>
    end
    <%- end -%>
end
<% end -%>
