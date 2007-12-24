class TypusController < ApplicationController

  before_filter :authenticate, :except => [ :login, :logout ]
  before_filter :set_model, :except => [ :dashboard, :login, :logout ]
  before_filter :set_order, :only => [ :index ]
  before_filter :find_model, :only => [ :show, :edit, :update, :destroy, :status ]
  before_filter :fields, :only => [ :index ]
  before_filter :form_fields, :only => [ :new, :edit, :create, :update ]

  def dashboard
  end

  def index
    conditions = "1 = 1 "
    conditions << (request.env['QUERY_STRING']).build_conditions(@model) if request.env['QUERY_STRING']
    @items = @model.paginate :page => params[:page], 
                             :per_page => Typus::Configuration.options[:per_page], 
                             :order => "#{params[:order_by]} #{params[:sort_order]}", 
                             :conditions => "#{conditions}"
  #rescue
  #  redirect_to :action => 'index'
  end

  def new
    @item = @model.new
  end

  def create
    @item = @model.new(params[:item])
    if @item.save
      flash[:notice] = "#{@model.to_s.capitalize} successfully created."
      redirect_to typus_index_url(params[:model])
    else
      render :action => 'new'
    end
  end

  def edit
    condition = ( @model.new.attributes.include? 'created_at' ) ? 'created_at' : 'id'
    current = ( condition == 'created_at' ) ? @item.created_at : @item.id
    @previous = @model.typus_find_previous(current, condition)
    @next = @model.typus_find_next(current, condition)
  end

  def update
    if @item.update_attributes(params[:item])
      flash[:notice] = "#{@model.to_s.capitalize} successfully updated."
      redirect_to typus_index_url(params[:model])
    else
      render :action => 'edit'
    end
  end

  def destroy
    @item.destroy
    flash[:notice] = "#{@model.to_s.capitalize} successfully removed."
    redirect_to typus_index_url(params[:model])
  end

  # Toggle the status of an item.
  def status
    @item.toggle!('status')
    flash[:notice] = "#{@model.to_s.capitalize} status changed"
    redirect_to :action => 'index'
  end

  # Relate a model object to another.
  def relate
    model_to_relate = params[:related].singularize.capitalize.constantize
    @model.find(params[:id]).send(params[:related]) << model_to_relate.find(params[:model_id_to_relate][:related_id])
    flash[:notice] = "#{model_to_relate} added to #{@model}"
    redirect_to :action => 'edit', :id => params[:id]
  end

  # Remove relationship between models.
  def unrelate
    model_to_unrelate = params[:unrelated].singularize.capitalize.constantize
    unrelate = model_to_unrelate.find(params[:unrelated_id])
    @model.find(params[:id]).send(params[:unrelated]).delete(unrelate)
    flash[:notice] = "#{model_to_unrelate} removed from #{@model}"
    redirect_to :action => 'edit', :id => params[:id]
  end

  # Runs model "extra actions". This is defined in +typus.yml+ as
  # +actions+.
  #
  # Post:
  #   actions: cleanup:index notify_users:edit
  #
  def run
    if params[:id]
      @model.find(params[:id]).send(params[:task]) if @model.actions.include? [params[:task], 'edit']
    else
      @model.send(params[:task]) if @model.actions.include? [params[:task], 'index']
    end
    flash[:notice] = "#{params[:task].humanize} performed."
    redirect_to :action => 'index'
  rescue
    flash[:notice] = "Undefined Action"
    redirect_to :action => 'index'
  end

  # Basic session creation.
  def login
    if request.post?
      username = Typus::Configuration.options[:username]
      password = Typus::Configuration.options[:password]
      if params[:user][:name] == username && params[:user][:password] == password
        session[:typus] = true
        redirect_to typus_dashboard_url
      else
        flash[:error] = "Username/Password Incorrect"
        redirect_to typus_login_url
      end
    else
      render :layout => 'typus_login'
    end
  end

  # End typus session and redirect to +typus_login+.
  def logout
    session[:typus] = nil
    redirect_to typus_login_url
  end

private

  # Set the current model.
  def set_model
    @model = params[:model].singularize.capitalize.constantize
  rescue
    redirect_to :action => 'dashboard'
  end

  # Set default order on the listings.
  def set_order
    order = @model.typus_defaults_for('order_by')
    if order
      params[:order_by] = params[:order_by] || order[0]
    else
      params[:order_by] = params[:order_by] || 'id'
    end
  end

  # Find
  def find_model
    @item = @model.find(params[:id])
  end

  # Model fields
  def fields
    @fields = @model.typus_fields_for("list")
  end

  # Model +form_fields+ & +form_externals+
  def form_fields
    @form_fields = @model.typus_fields_for('form')
    @form_fields_externals = @model.typus_defaults_for('related')
  end

private

  # Authenticate
  def authenticate
    redirect_to typus_login_url unless session[:typus]
  end

end
