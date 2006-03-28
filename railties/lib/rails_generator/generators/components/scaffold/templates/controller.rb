class <%= controller_class_name %>Controller < ApplicationController
<% unless suffix -%>
  def index
    list
    render :action => 'list'
  end
<% end -%>

<% for action in unscaffolded_actions -%>
  def <%= action %><%= suffix %>
  end

<% end -%>
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy<%= suffix %>, :create<%= suffix %>, :update<%= suffix %> ],
         :redirect_to => { :action => :list<%= suffix %> }

  def list<%= suffix %>
    @<%= singular_name %>_pages, @<%= plural_name %> = paginate :<%= plural_name %>, :per_page => 10
  end

  def show<%= suffix %>
    @<%= singular_name %> = <%= model_name %>.find(params[:id])
  end

  def new<%= suffix %>
    @<%= singular_name %> = <%= model_name %>.new
  end

  def create<%= suffix %>
    @<%= singular_name %> = <%= model_name %>.new(params[:<%= singular_name %>])
    if @<%= singular_name %>.save
      flash[:notice] = '<%= model_name %> was successfully created.'
      redirect_to :action => 'list<%= suffix %>'
    else
      render :action => 'new<%= suffix %>'
    end
  end

  def edit<%= suffix %>
    @<%= singular_name %> = <%= model_name %>.find(params[:id])
  end

  def update
    @<%= singular_name %> = <%= model_name %>.find(params[:id])
    if @<%= singular_name %>.update_attributes(params[:<%= singular_name %>])
      flash[:notice] = '<%= model_name %> was successfully updated.'
      redirect_to :action => 'show<%= suffix %>', :id => @<%= singular_name %>
    else
      render :action => 'edit<%= suffix %>'
    end
  end

  def destroy<%= suffix %>
    <%= model_name %>.find(params[:id]).destroy
    redirect_to :action => 'list<%= suffix %>'
  end
end
