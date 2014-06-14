VALID_ON_OPTIONS  = [:new, :collection, :member]
RESOURCE_OPTIONS  = [:as, :controller, :path, :only, :except, :param, :concerns]
CANONICAL_ACTIONS = %w(index create new show update destroy)
RESOURCE_METHOD_SCOPES = [:collection, :member, :new]
RESOURCE_SCOPES = [:resource, :resources]

class Resource #:nodoc:
  attr_reader :controller, :path, :options, :param

  def initialize(entities, options = {})
    @name       = entities.to_s
    @path       = (options[:path] || @name).to_s
    @controller = (options[:controller] || @name).to_s
    @as         = options[:as]
    @param      = (options[:param] || :id).to_sym
    @options    = options
    @shallow    = false
  end

  def default_actions
    [:index, :create, :new, :show, :update, :destroy, :edit]
  end

  def actions
    if only = @options[:only]
      Array(only).map(&:to_sym)
    elsif except = @options[:except]
      default_actions - Array(except).map(&:to_sym)
    else
      default_actions
    end
  end

  def name
    @as || @name
  end

  def plural
    @plural ||= name.to_s
  end

  def singular
    @singular ||= name.to_s.singularize
  end

  alias :member_name :singular

  def collection_name
    singular == plural ? "#{plural}_index" : plural
  end

  def resource_scope
    { :controller => controller }
  end

  alias :collection_scope :path

  def member_scope
    "#{path}/:#{param}"
  end

  alias :shallow_scope :member_scope

  def new_scope(new_path)
    "#{path}/#{new_path}"
  end

  def nested_param
    :"#{singular}_#{param}"
  end

  def nested_scope
    "#{path}/:#{nested_param}"
  end

  def shallow=(value)
    @shallow = value
  end

  def shallow?
    @shallow
  end
end

class SingletonResource < Resource #:nodoc:
  def initialize(entities, options)
    super
    @as         = nil
    @controller = (options[:controller] || plural).to_s
    @as         = options[:as]
  end

  def default_actions
    [:show, :create, :update, :destroy, :new, :edit]
  end

  def plural
    @plural ||= name.to_s.pluralize
  end

  def singular
    @singular ||= name.to_s
  end

  alias :member_name :singular
  alias :collection_name :singular

  alias :member_scope :path
  alias :nested_scope :path
end

def resources_path_names(options)
  @scope[:path_names].merge!(options)
end

def resource(*resources, &block)
  options = resources.extract_options!.dup

  if apply_common_behavior_for(:resource, resources, options, &block)
    return self
  end

  resource_scope(:resource, SingletonResource.new(resources.pop, options)) do
    yield if block_given?

    concerns(options[:concerns]) if options[:concerns]

    collection do
      post :create
    end if parent_resource.actions.include?(:create)

    new do
      get :new
    end if parent_resource.actions.include?(:new)

    set_member_mappings_for_resource
  end

  self
end

def resources(*resources, &block)
  options = resources.extract_options!.dup

  if apply_common_behavior_for(:resources, resources, options, &block)
    return self
  end

  resource_scope(:resources, Resource.new(resources.pop, options)) do
    yield if block_given?

    concerns(options[:concerns]) if options[:concerns]

    collection do
      get  :index if parent_resource.actions.include?(:index)
      post :create if parent_resource.actions.include?(:create)
    end

    new do
      get :new
    end if parent_resource.actions.include?(:new)

    set_member_mappings_for_resource
  end

  self
end

def collection
  unless resource_scope?
    raise ArgumentError, "can't use collection outside resource(s) scope"
  end

  with_scope_level(:collection) do
    scope(parent_resource.collection_scope) do
      yield
    end
  end
end

def member
  unless resource_scope?
    raise ArgumentError, "can't use member outside resource(s) scope"
  end

  with_scope_level(:member) do
    if shallow?
      shallow_scope(parent_resource.member_scope) { yield }
    else
      scope(parent_resource.member_scope) { yield }
    end
  end
end

def new
  unless resource_scope?
    raise ArgumentError, "can't use new outside resource(s) scope"
  end

  with_scope_level(:new) do
    scope(parent_resource.new_scope(action_path(:new))) do
      yield
    end
  end
end

def nested
  unless resource_scope?
    raise ArgumentError, "can't use nested outside resource(s) scope"
  end

  with_scope_level(:nested) do
    if shallow? && shallow_nesting_depth > 1
      shallow_scope(parent_resource.nested_scope, nested_options) { yield }
    else
      scope(parent_resource.nested_scope, nested_options) { yield }
    end
  end
end

# See ActionDispatch::Routing::Mapper::Scoping#namespace
def namespace(path, options = {})
  if resource_scope?
    nested { super }
  else
    super
  end
end

def shallow
  scope(:shallow => true) do
    yield
  end
end

def shallow?
  parent_resource.instance_of?(Resource) && @scope[:shallow]
end

def match(path, *rest)
  if rest.empty? && Hash === path
    options  = path
    path, to = options.find { |name, _value| name.is_a?(String) }

    case to
    when Symbol
      options[:action] = to
    when String
      if to =~ /#/
        options[:to] = to
      else
        options[:controller] = to
      end
    else
      options[:to] = to
    end

    options.delete(path)
    paths = [path]
  else
    options = rest.pop || {}
    paths = [path] + rest
  end

  options[:anchor] = true unless options.key?(:anchor)

  if options[:on] && !VALID_ON_OPTIONS.include?(options[:on])
    raise ArgumentError, "Unknown scope #{on.inspect} given to :on"
  end

  if @scope[:controller] && @scope[:action]
    options[:to] ||= "#{@scope[:controller]}##{@scope[:action]}"
  end

  paths.each do |_path|
    route_options = options.dup
    route_options[:path] ||= _path if _path.is_a?(String)

    path_without_format = _path.to_s.sub(/\(\.:format\)$/, '')
    if using_match_shorthand?(path_without_format, route_options)
      route_options[:to] ||= path_without_format.gsub(%r{^/}, "").sub(%r{/([^/]*)$}, '#\1')
      route_options[:to].tr!("-", "_")
    end

    decomposed_match(_path, route_options)
  end
  self
end

def using_match_shorthand?(path, options)
  path && (options[:to] || options[:action]).nil? && path =~ %r{/[\w/]+$}
end

def decomposed_match(path, options) # :nodoc:
  if on = options.delete(:on)
    send(on) { decomposed_match(path, options) }
  else
    case @scope[:scope_level]
    when :resources
      nested { decomposed_match(path, options) }
    when :resource
      member { decomposed_match(path, options) }
    else
      add_route(path, options)
    end
  end
end

def add_route(action, options) # :nodoc:
  path = path_for_action(action, options.delete(:path))
  raise ArgumentError, "path is required" if path.blank?

  action = action.to_s.dup

  if action =~ /^[\w\-\/]+$/
    options[:action] ||= action.tr('-', '_') unless action.include?("/")
  else
    action = nil
  end

  if !options.fetch(:as, true)
    options.delete(:as)
  else
    options[:as] = name_for_action(options[:as], action)
  end

  mapping = Mapping.build(@scope, URI.parser.escape(path), options)
  app, conditions, requirements, defaults, as, anchor = mapping.to_route
  @set.add_route(app, conditions, requirements, defaults, as, anchor)
end

def root(path, options={})
  if path.is_a?(String)
    options[:to] = path
  elsif path.is_a?(Hash) and options.empty?
    options = path
  else
    raise ArgumentError, "must be called with a path and/or options"
  end

  if @scope[:scope_level] == :resources
    with_scope_level(:root) do
      scope(parent_resource.path) do
        super(options)
      end
    end
  else
    super(options)
  end
end

protected

  def parent_resource #:nodoc:
    @scope[:scope_level_resource]
  end

  def apply_common_behavior_for(method, resources, options, &block) #:nodoc:
    if resources.length > 1
      resources.each { |r| send(method, r, options, &block) }
      return true
    end

    if options.delete(:shallow)
      shallow do
        send(method, resources.pop, options, &block)
      end
      return true
    end

    if resource_scope?
      nested { send(method, resources.pop, options, &block) }
      return true
    end

    options.keys.each do |k|
      (options[:constraints] ||= {})[k] = options.delete(k) if options[k].is_a?(Regexp)
    end

    scope_options = options.slice!(*RESOURCE_OPTIONS)
    unless scope_options.empty?
      scope(scope_options) do
        send(method, resources.pop, options, &block)
      end
      return true
    end

    unless action_options?(options)
      options.merge!(scope_action_options) if scope_action_options?
    end

    false
  end

  def action_options?(options) #:nodoc:
    options[:only] || options[:except]
  end

  def scope_action_options? #:nodoc:
    @scope[:options] && (@scope[:options][:only] || @scope[:options][:except])
  end

  def scope_action_options #:nodoc:
    @scope[:options].slice(:only, :except)
  end

  def resource_scope? #:nodoc:
    RESOURCE_SCOPES.include? @scope[:scope_level]
  end

  def resource_method_scope? #:nodoc:
    RESOURCE_METHOD_SCOPES.include? @scope[:scope_level]
  end

  def nested_scope? #:nodoc:
    @scope[:scope_level] == :nested
  end

  def with_exclusive_scope
    begin
      old_name_prefix, old_path = @scope[:as], @scope[:path]
      @scope[:as], @scope[:path] = nil, nil

      with_scope_level(:exclusive) do
        yield
      end
    ensure
      @scope[:as], @scope[:path] = old_name_prefix, old_path
    end
  end

  def with_scope_level(kind)
    old, @scope[:scope_level] = @scope[:scope_level], kind
    yield
  ensure
    @scope[:scope_level] = old
  end

  def resource_scope(kind, resource) #:nodoc:
    resource.shallow = @scope[:shallow]
    old_resource, @scope[:scope_level_resource] = @scope[:scope_level_resource], resource
    @nesting.push(resource)

    with_scope_level(kind) do
      scope(parent_resource.resource_scope) { yield }
    end
  ensure
    @nesting.pop
    @scope[:scope_level_resource] = old_resource
  end

  def nested_options #:nodoc:
    options = { :as => parent_resource.member_name }
    options[:constraints] = {
      parent_resource.nested_param => param_constraint
    } if param_constraint?

    options
  end

  def nesting_depth #:nodoc:
    @nesting.size
  end

  def shallow_nesting_depth #:nodoc:
    @nesting.select(&:shallow?).size
  end

  def param_constraint? #:nodoc:
    @scope[:constraints] && @scope[:constraints][parent_resource.param].is_a?(Regexp)
  end

  def param_constraint #:nodoc:
    @scope[:constraints][parent_resource.param]
  end

  def canonical_action?(action, flag) #:nodoc:
    flag && resource_method_scope? && CANONICAL_ACTIONS.include?(action.to_s)
  end

  def shallow_scope(path, options = {}) #:nodoc:
    old_name_prefix, old_path = @scope[:as], @scope[:path]
    @scope[:as], @scope[:path] = @scope[:shallow_prefix], @scope[:shallow_path]

    scope(path, options) { yield }
  ensure
    @scope[:as], @scope[:path] = old_name_prefix, old_path
  end

  def path_for_action(action, path) #:nodoc:
    if canonical_action?(action, path.blank?)
      @scope[:path].to_s
    else
      "#{@scope[:path]}/#{action_path(action, path)}"
    end
  end

  def action_path(name, path = nil) #:nodoc:
    name = name.to_sym if name.is_a?(String)
    path || @scope[:path_names][name] || name.to_s
  end

  def prefix_name_for_action(as, action) #:nodoc:
    if as
      prefix = as
    elsif !canonical_action?(action, @scope[:scope_level])
      prefix = action
    end
    prefix.to_s.tr('-', '_') if prefix
  end

  def name_for_action(as, action) #:nodoc:
    prefix = prefix_name_for_action(as, action)
    prefix = Mapper.normalize_name(prefix) if prefix
    name_prefix = @scope[:as]

    if parent_resource
      return nil unless as || action

      collection_name = parent_resource.collection_name
      member_name = parent_resource.member_name
    end

    name = case @scope[:scope_level]
    when :nested
      [name_prefix, prefix]
    when :collection
      [prefix, name_prefix, collection_name]
    when :new
      [prefix, :new, name_prefix, member_name]
    when :member
      [prefix, name_prefix, member_name]
    when :root
      [name_prefix, collection_name, prefix]
    else
      [name_prefix, member_name, prefix]
    end

    if candidate = name.select(&:present?).join("_").presence
      # If a name was not explicitly given, we check if it is valid
      # and return nil in case it isn't. Otherwise, we pass the invalid name
      # forward so the underlying router engine treats it and raises an exception.
      if as.nil?
        candidate unless @set.routes.find { |r| r.name == candidate } || candidate !~ /\A[_a-z]/i
      else
        candidate
      end
    end
  end

  def set_member_mappings_for_resource
    member do
      get :edit if parent_resource.actions.include?(:edit)
      get :show if parent_resource.actions.include?(:show)
      if parent_resource.actions.include?(:update)
        patch :update
        put   :update
      end
      delete :destroy if parent_resource.actions.include?(:destroy)
    end
  end
