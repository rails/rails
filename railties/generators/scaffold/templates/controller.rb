class <%= @controller_class_name %>Controller < ApplicationController
<% unless suffix -%>
  def index
    list
    render_action 'list'
  end
<% end -%>

<% for action in unscaffolded_actions -%>
  def <%= action %><%= suffix %>
  end

<% end -%>
  def list<%= suffix %>
    @<%= plural_name %> = <%= class_name %>.find_all
  end

  def show<%= suffix %>
    @<%= singular_name %> = <%= class_name %>.find(@params['id'])
  end

  def new<%= suffix %>
    @<%= singular_name %> = <%= class_name %>.new
  end

  def create<%= suffix %>
    @<%= singular_name %> = <%= class_name %>.new(@params['<%= singular_name %>'])
    if @<%= singular_name %>.save
      flash['notice'] = '<%= class_name %> was successfully created.'
      redirect_to :action => 'list<%= suffix %>'
    else
      render_action 'new<%= suffix %>'
    end
  end

  def edit<%= suffix %>
    @<%= singular_name %> = <%= class_name %>.find(@params['id'])
  end

  def update
    @<%= singular_name %> = <%= class_name %>.find(@params['<%= singular_name %>']['id'])
    if @<%= singular_name %>.update_attributes(@params['<%= singular_name %>'])
      flash['notice'] = '<%= class_name %> was successfully updated.'
      redirect_to :action => 'show<%= suffix %>', :id => @<%= singular_name %>.id
    else
      render_action 'edit<%= suffix %>'
    end
  end

  def destroy<%= suffix %>
    <%= class_name %>.find(@params['id']).destroy
    redirect_to :action => 'list<%= suffix %>'
  end
end
