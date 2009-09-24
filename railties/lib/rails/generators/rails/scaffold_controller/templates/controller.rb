class <%= controller_class_name %>Controller < ApplicationController
<% unless options[:singleton] -%>
  # GET /<%= table_name %>
  # GET /<%= table_name %>.xml
  def index
    @<%= table_name %> = <%= orm_class.all(class_name) %>

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @<%= table_name %> }
    end
  end
<% end -%>

  # GET /<%= table_name %>/1
  # GET /<%= table_name %>/1.xml
  def show
    @<%= file_name %> = <%= orm_class.find(class_name, "params[:id]") %>

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @<%= file_name %> }
    end
  end

  # GET /<%= table_name %>/new
  # GET /<%= table_name %>/new.xml
  def new
    @<%= file_name %> = <%= orm_class.build(class_name) %>

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @<%= file_name %> }
    end
  end

  # GET /<%= table_name %>/1/edit
  def edit
    @<%= file_name %> = <%= orm_class.find(class_name, "params[:id]") %>
  end

  # POST /<%= table_name %>
  # POST /<%= table_name %>.xml
  def create
    @<%= file_name %> = <%= orm_class.build(class_name, "params[:#{file_name}]") %>

    respond_to do |format|
      if @<%= orm_instance.save %>
        flash[:notice] = '<%= class_name %> was successfully created.'
        format.html { redirect_to(@<%= file_name %>) }
        format.xml  { render :xml => @<%= file_name %>, :status => :created, :location => @<%= file_name %> }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @<%= orm_instance.errors %>, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /<%= table_name %>/1
  # PUT /<%= table_name %>/1.xml
  def update
    @<%= file_name %> = <%= orm_class.find(class_name, "params[:id]") %>

    respond_to do |format|
      if @<%= orm_instance.update_attributes("params[:#{file_name}]") %>
        flash[:notice] = '<%= class_name %> was successfully updated.'
        format.html { redirect_to(@<%= file_name %>) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @<%= orm_instance.errors %>, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /<%= table_name %>/1
  # DELETE /<%= table_name %>/1.xml
  def destroy
    @<%= file_name %> = <%= orm_class.find(class_name, "params[:id]") %>
    @<%= orm_instance.destroy %>

    respond_to do |format|
      format.html { redirect_to(<%= table_name %>_url) }
      format.xml  { head :ok }
    end
  end
end
