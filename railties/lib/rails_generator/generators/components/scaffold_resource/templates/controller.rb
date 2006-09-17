class <%= controller_class_name %>Controller < ApplicationController
  # GET /<%= table_name %>
  # GET /<%= table_name %>.xml
  def index
    @<%= table_name %> = <%= class_name %>.find(:all)

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @<%= table_name %>.to_xml }
    end
  end
  
  # GET /<%= table_name %>/1
  # GET /<%= table_name %>/1.xml
  def show
    @<%= file_name %> = <%= class_name %>.find(params[:id])
    
    respond_to do |format|
      format.html # show.rhtml
      format.xml  { render :xml => @<%= file_name %>.to_xml }
    end
  end
  
  # GET /<%= table_name %>/new
  def new
    @<%= file_name %> = <%= class_name %>.new
  end
  
  # GET /<%= table_name %>/1;edit
  def edit
    @<%= file_name %> = <%= class_name %>.find(params[:id])
  end

  # POST /<%= table_name %>
  # POST /<%= table_name %>.xml
  def create
    @<%= file_name %> = <%= class_name %>.new(params[:<%= file_name %>])
    
    respond_to do |format|
      if @<%= file_name %>.save
        flash[:notice] = '<%= class_name %> was successfully created.'
        
        format.html { redirect_to <%= file_name %>_url(@<%= file_name %>) }
        format.xml do
          headers["Location"] = <%= file_name %>_url(@<%= file_name %>)
          render :nothing => true, :status => "201 Created"
        end
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @<%= file_name %>.errors.to_xml }
      end
    end
  end
  
  # PUT /<%= table_name %>/1
  # PUT /<%= table_name %>/1.xml
  def update
    @<%= file_name %> = <%= class_name %>.find(params[:id])
    
    respond_to do |format|
      if @<%= file_name %>.update_attributes(params[:<%= file_name %>])
        format.html { redirect_to <%= file_name %>_url(@<%= file_name %>) }
        format.xml  { render :nothing => true }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @<%= file_name %>.errors.to_xml }        
      end
    end
  end
  
  # DELETE /<%= table_name %>/1
  # DELETE /<%= table_name %>/1.xml
  def destroy
    @<%= file_name %> = <%= class_name %>.find(params[:id])
    @<%= file_name %>.destroy
    
    respond_to do |format|
      format.html { redirect_to <%= table_name %>_url   }
      format.xml  { render :nothing => true }
    end
  end
end