h2. Ruby on Rails 4.0 Release Notes

Highlights in Rails 4.0:

These release notes cover the major changes, but do not include each bug-fix and changes. If you want to see everything, check out the "list of commits":https://github.com/rails/rails/commits/master in the main Rails repository on GitHub.

endprologue.

h3. Upgrading to Rails 4.0

TODO. This is a WIP guide.

If you're upgrading an existing application, it's a great idea to have good test coverage before going in. You should also first upgrade to Rails 3.2 in case you haven't and make sure your application still runs as expected before attempting an update to Rails 4.0. Then take heed of the following changes:

h4. Rails 4.0 requires at least Ruby 1.9.3

Rails 4.0 requires Ruby 1.9.3 or higher. Support for all of the previous Ruby versions has been dropped officially and you should upgrade as early as possible.

h4. What to update in your apps

* Update your Gemfile to depend on
** <tt>rails = 4.0.0</tt>
** <tt>sass-rails ~> 3.2.3</tt>
** <tt>coffee-rails ~> 3.2.1</tt>
** <tt>uglifier >= 1.0.3</tt>

TODO: Update the versions above.

* Rails 4.0 removes <tt>vendor/plugins</tt> completely. You have to replace these plugins by extracting them as gems and adding them in your Gemfile. If you choose not to make them gems, you can move them into, say, <tt>lib/my_plugin/*</tt> and add an appropriate initializer in <tt>config/initializers/my_plugin.rb</tt>.

TODO: Configuration changes in environment files

h3. Creating a Rails 4.0 application

<shell>
# You should have the 'rails' rubygem installed
$ rails new myapp
$ cd myapp
</shell>

h4. Vendoring Gems

Rails now uses a +Gemfile+ in the application root to determine the gems you require for your application to start. This +Gemfile+ is processed by the "Bundler":https://github.com/carlhuda/bundler gem, which then installs all your dependencies. It can even install all the dependencies locally to your application so that it doesn't depend on the system gems.

More information: "Bundler homepage":http://gembundler.com

h4. Living on the Edge

+Bundler+ and +Gemfile+ makes freezing your Rails application easy as pie with the new dedicated +bundle+ command. If you want to bundle straight from the Git repository, you can pass the +--edge+ flag:

<shell>
$ rails new myapp --edge
</shell>

If you have a local checkout of the Rails repository and want to generate an application using that, you can pass the +--dev+ flag:

<shell>
$ ruby /path/to/rails/railties/bin/rails new myapp --dev
</shell>

h3. Major Features

h3. Documentation

h3. Railties

* Allow scaffold/model/migration generators to accept a <tt>polymorphic</tt> modifier for <tt>references</tt>/<tt>belongs_to</tt>, for instance

<shell>
rails g model Product supplier:references{polymorphic}
</shell>

will generate the model with <tt>belongs_to :supplier, polymorphic: true</tt> association and appropriate migration.

* Set <tt>config.active_record.migration_error</tt> to <tt>:page_load</tt> for development.

* Add runner to <tt>Rails::Railtie</tt> as a hook called just after runner starts.

* Add <tt>/rails/info/routes</tt> path which displays the same information as +rake routes+.

* Improved +rake routes+ output for redirects.

* Load all environments available in <tt>config.paths["config/environments"]</tt>.

* Add <tt>config.queue_consumer</tt> to allow the default consumer to be configurable.

* Add <tt>Rails.queue</tt> as an interface with a default implementation that consumes jobs in a separate thread.

* Remove <tt>Rack::SSL</tt> in favour of <tt>ActionDispatch::SSL</tt>.

* Allow to set class that will be used to run as a console, other than IRB, with <tt>Rails.application.config.console=</tt>. It's best to add it to console block.

<ruby>
# it can be added to config/application.rb
console do
  # this block is called only when running console,
  # so we can safely require pry here
  require "pry"
  config.console = Pry
end
</ruby>

* Add a convenience method <tt>hide!</tt> to Rails generators to hide the current generator namespace from showing when running <tt>rails generate</tt>.

* Scaffold now uses +content_tag_for+ in <tt>index.html.erb</tt>.

* <tt>Rails::Plugin</tt> is removed. Instead of adding plugins to <tt>vendor/plugins</tt>, use gems or bundler with path or git dependencies.

h4(#railties_deprecations). Deprecations

h3. Action Mailer

* Allow to set default Action Mailer options via <tt>config.action_mailer.default_options=</tt>.

* Raise an <tt>ActionView::MissingTemplate</tt> exception when no implicit template could be found.

* Asynchronously send messages via the Rails Queue.

* Delivery Options (such as SMTP Settings) can now be set dynamically per mailer action. 

Delivery options are set via <tt>:delivery_method_options</tt> key on mail.

<ruby>
def welcome_mailer(user,company)
  mail to: user.email, 
       subject: "Welcome!", 
       delivery_method_options: {user_name: company.smtp_user,
                                 password: company.smtp_password,
                                 address: company.smtp_server}
end
</ruby>

h3. Action Pack

h4. Action Controller

* Add <tt>ActionController::Flash.add_flash_types</tt> method to allow people to register their own flash types. e.g.:

<ruby>
class ApplicationController
  add_flash_types :error, :warning
end
</ruby>

If you add the above code, you can use <tt><%= error %></tt> in an erb, and <tt>redirect_to /foo, :error => 'message'</tt> in a controller.

* Remove Active Model dependency from Action Pack.

* Support unicode characters in routes. Route will be automatically escaped, so instead of manually escaping:

<ruby>
get Rack::Utils.escape('こんにちは') => 'home#index'
</ruby>

You just have to write the unicode route:

<ruby>
get 'こんにちは' => 'home#index'
</ruby>

* Return proper format on exceptions.

* Extracted redirect logic from <tt>ActionController::ForceSSL::ClassMethods.force_ssl</tt>  into <tt>ActionController::ForceSSL#force_ssl_redirect</tt>.

* URL path parameters with invalid encoding now raise <tt>ActionController::BadRequest</tt>.

* Malformed query and request parameter hashes now raise <tt>ActionController::BadRequest</tt>.

* +respond_to+ and +respond_with+ now raise <tt>ActionController::UnknownFormat</tt> instead of directly returning head 406. The exception is rescued and converted to 406 in the exception handling middleware.

* JSONP now uses <tt>application/javascript</tt> instead of <tt>application/json</tt> as the MIME type.

* Session arguments passed to process calls in functional tests are now merged into the existing session, whereas previously they would replace the existing session.  This change may break some existing tests if they are asserting the exact contents of the session but should not break existing tests that only assert individual keys.

* Forms of persisted records use always PATCH (via the +_method+ hack).

* For resources, both PATCH and PUT are routed to the +update+ action.

* Don't ignore +force_ssl+ in development. This is a change of behavior - use an <tt>:if</tt> condition to recreate the old behavior.

<ruby>
class AccountsController < ApplicationController
  force_ssl :if => :ssl_configured?

  def ssl_configured?
    !Rails.env.development?
  end
end
</ruby>

h5(#actioncontroller_deprecations). Deprecations

* Deprecated <tt>ActionController::Integration</tt> in favour of <tt>ActionDispatch::Integration</tt>.

* Deprecated <tt>ActionController::IntegrationTest</tt> in favour of <tt>ActionDispatch::IntegrationTest</tt>.

* Deprecated <tt>ActionController::PerformanceTest</tt> in favour of <tt>ActionDispatch::PerformanceTest</tt>.

* Deprecated <tt>ActionController::AbstractRequest</tt> in favour of <tt>ActionDispatch::Request</tt>.

* Deprecated <tt>ActionController::Request</tt> in favour of <tt>ActionDispatch::Request</tt>.

* Deprecated <tt>ActionController::AbstractResponse</tt> in favour of <tt>ActionDispatch::Response</tt>.

* Deprecated <tt>ActionController::Response</tt> in favour of <tt>ActionDispatch::Response</tt>.

* Deprecated <tt>ActionController::Routing</tt> in favour of <tt>ActionDispatch::Routing</tt>.

h4. Action Dispatch

* Add Routing Concerns to declare common routes that can be reused inside others resources and routes.

Code before:

<ruby>
resources :messages do
  resources :comments
end

resources :posts do
  resources :comments
  resources :images, only: :index
end
</ruby>

Code after:

<ruby>
concern :commentable do
  resources :comments
end

concern :image_attachable do
  resources :images, only: :index
end

resources :messages, concerns: :commentable

resources :posts, concerns: [:commentable, :image_attachable]
</ruby>

* Show routes in exception page while debugging a <tt>RoutingError</tt> in development.

* Include <tt>mounted_helpers</tt> (helpers for accessing mounted engines) in <tt>ActionDispatch::IntegrationTest</tt> by default.

* Added <tt>ActionDispatch::SSL</tt> middleware that when included force all the requests to be under HTTPS protocol.

* Copy literal route constraints to defaults so that url generation know about them.  The copied constraints are <tt>:protocol</tt>, <tt>:subdomain</tt>, <tt>:domain</tt>, <tt>:host</tt> and <tt>:port</tt>.

* Allows +assert_redirected_to+ to match against a regular expression.

* Adds a backtrace to the routing error page in development.

* +assert_generates+, +assert_recognizes+, and +assert_routing+ all raise +Assertion+ instead of +RoutingError+.

* Allows the route helper root to take a string argument. For example, <tt>root 'pages#main'</tt> as a shortcut for <tt>root to: 'pages#main'</tt>.

* Adds support for the PATCH verb: Request objects respond to <tt>patch?</tt>. Routes now have a new +patch+ method, and understand +:patch+ in the existing places where a verb is configured, like <tt>:via</tt>. Functional tests have a new method +patch+ and integration tests have a new method +patch_via_redirect+.
If <tt>:patch</tt> is the default verb for updates, edits are tunneled as <tt>PATCH</tt> rather than as <tt>PUT</tt> and routing acts accordingly.

* Integration tests support the OPTIONS method.

* +expires_in+ accepts a +must_revalidate+ flag. If true, "must-revalidate" is added to the <tt>Cache-Control</tt> header.

* Default responder will now always use your overridden block in <tt>respond_with</tt> to render your response.

* Turn off verbose mode of <tt>rack-cache</tt>, we still have <tt>X-Rack-Cache</tt> to check that info.

h5(#actiondispatch_deprecations). Deprecations

h4. Action View

* Remove Active Model dependency from Action Pack.

* Allow to use <tt>mounted_helpers</tt> (helpers for accessing mounted engines) in <tt>ActionView::TestCase</tt>.

* Make current object and counter (when it applies) variables accessible when rendering templates with <tt>:object</tt> or <tt>:collection</tt>.

* Allow to lazy load +default_form_builder+ by passing a string instead of a constant.

* Add index method to +FormBuilder+ class.

* Adds support for layouts when rendering a partial with a given collection.

* Remove <tt>:disable_with</tt> in favor of <tt>data-disable-with</tt> option from +submit_tag+, +button_tag+ and +button_to+ helpers.

* Remove <tt>:mouseover</tt> option from +image_tag+ helper.

* Templates without a handler extension now raises a deprecation warning but still defaults to +ERb+. In future releases, it will simply return the template content.

* Add a +divider+ option to +grouped_options_for_select+ to generate a separator optgroup automatically, and deprecate prompt as third argument, in favor of using an options hash.

* Add +time_field+ and +time_field_tag+ helpers which render an <tt>input[type="time"]</tt> tag.

* Removed old +text_helper+ apis for +highlight+, +excerpt+ and +word_wrap+.

* Remove the leading \n added by textarea on +assert_select+.

* Changed default value for <tt>config.action_view.embed_authenticity_token_in_remote_forms</tt> to false. This change breaks remote forms that need to work also without JavaScript, so if you need such behavior, you can either set it to true or explicitly pass <tt>:authenticity_token => true</tt> in form options.

* Make possible to use a block in +button_to+ helper if button text is hard to fit into the name parameter:

<ruby>
<%= button_to [:make_happy, @user] do %>
  Make happy <strong><%= @user.name %></strong>
<% end %>
# => "<form method="post" action="/users/1/make_happy" class="button_to">
#      <div>
#        <button type="submit">
#          Make happy <strong>Name</strong>
#        </button>
#      </div>
#    </form>"
</ruby>

* Replace +include_seconds+ boolean argument with <tt>:include_seconds => true</tt> option in +distance_of_time_in_words+ and +time_ago_in_words+ signature.

* Remove +button_to_function+ and +link_to_function+ helpers.

* +truncate+ now always returns an escaped HTML-safe string. The option <tt>:escape</tt> can be used as +false+ to not escape the result.

* +truncate+ now accepts a block to show extra content when the text is truncated.

* Add +week_field+, +week_field_tag+, +month_field+, +month_field_tag+, +datetime_local_field+, +datetime_local_field_tag+, +datetime_field+ and +datetime_field_tag+ helpers.

* Add +color_field+ and +color_field_tag+ helpers.

* Add +include_hidden+ option to select tag. With <tt>:include_hidden => false</tt> select with multiple attribute doesn't generate hidden input with blank value.

* Removed default size option from the +text_field+, +search_field+, +telephone_field+, +url_field+, +email_field+ helpers.

* Removed default cols and rows options from the +text_area+ helper.

* Adds +image_url+, +javascript_url+, +stylesheet_url+, +audio_url+, +video_url+, and +font_url+ to assets tag helper. These URL helpers will return the full path to your assets. This is useful when you are going to reference this asset from external host.

* Allow +value_method+ and +text_method+ arguments from +collection_select+ and +options_from_collection_for_select+ to receive an object that responds to <tt>:call</tt> such as a proc, to evaluate the option in the current element context. This works the same way with +collection_radio_buttons+ and +collection_check_boxes+.

* Add +date_field+ and +date_field_tag+ helpers which render an <tt>input[type="date"]</tt> tag.

* Add +collection_check_boxes+ form helper, similar to +collection_select+:

<ruby>
collection_check_boxes :post, :author_ids, Author.all, :id, :name
# Outputs something like:
<input id="post_author_ids_1" name="post[author_ids][]" type="checkbox" value="1" />
<label for="post_author_ids_1">D. Heinemeier Hansson</label>
<input id="post_author_ids_2" name="post[author_ids][]" type="checkbox" value="2" />
<label for="post_author_ids_2">D. Thomas</label>
<input name="post[author_ids][]" type="hidden" value="" />
</ruby>

The label/check_box pairs can be customized with a block.

* Add +collection_radio_buttons+ form helper, similar to +collection_select+:

<ruby>
collection_radio_buttons :post, :author_id, Author.all, :id, :name
# Outputs something like:
<input id="post_author_id_1" name="post[author_id]" type="radio" value="1" />
<label for="post_author_id_1">D. Heinemeier Hansson</label>
<input id="post_author_id_2" name="post[author_id]" type="radio" value="2" />
<label for="post_author_id_2">D. Thomas</label>
</ruby>

The label/radio_button pairs can be customized with a block.

* +check_box+ with an HTML5 attribute +:form+ will now replicate the +:form+ attribute to the hidden field as well.

* label form helper accepts <tt>:for => nil</tt> to not generate the attribute.

* Add <tt>:format</tt> option to +number_to_percentage+.

* Add <tt>config.action_view.logger</tt> to configure logger for +Action View+.

* +check_box+ helper with <tt>:disabled => true</tt> will generate a +disabled+ hidden field to conform with the HTML convention where disabled fields are not submitted with the form. This is a behavior change, previously the hidden tag had a value of the disabled checkbox.

* +favicon_link_tag+ helper will now use the favicon in <tt>app/assets</tt> by default.

* <tt>ActionView::Helpers::TextHelper#highlight</tt> now defaults to the HTML5 +mark+ element.

h5(#actionview_deprecations). Deprecations

h4. Sprockets

Moved into a separate gem <tt>sprockets-rails</tt>.

h3. Active Record

* Add <tt>add_reference</tt> and <tt>remove_reference</tt> schema statements. Aliases, <tt>add_belongs_to</tt> and <tt>remove_belongs_to</tt> are acceptable. References are reversible.

<ruby>
# Create a user_id column
add_reference(:products, :user)

# Create a supplier_id, supplier_type columns and appropriate index
add_reference(:products, :supplier, polymorphic: true, index: true)

# Remove polymorphic reference
remove_reference(:products, :supplier, polymorphic: true)
</ruby>


* Add <tt>:default</tt> and <tt>:null</tt> options to <tt>column_exists?</tt>.

<ruby>
column_exists?(:testings, :taggable_id, :integer, null: false)
column_exists?(:testings, :taggable_type, :string, default: 'Photo')
</ruby>

* <tt>ActiveRecord::Relation#inspect</tt> now makes it clear that you are dealing with a <tt>Relation</tt> object rather than an array:

<ruby>
User.where(:age => 30).inspect
# => <ActiveRecord::Relation [#<User ...>, #<User ...>]>

User.where(:age => 30).to_a.inspect
# => [#<User ...>, #<User ...>]
</ruby>

if more than 10 items are returned by the relation, inspect will only show the first 10 followed by ellipsis.

* Add <tt>:collation</tt> and <tt>:ctype</tt> support to PostgreSQL. These are available for PostgreSQL 8.4 or later.

<yaml>
development:
  adapter: postgresql
  host: localhost
  database: rails_development
  username: foo
  password: bar
  encoding: UTF8
  collation: ja_JP.UTF8
  ctype: ja_JP.UTF8
</yaml>

* <tt>FinderMethods#exists?</tt> now returns <tt>false</tt> with the <tt>false</tt> argument.

* Added support for specifying the precision of a timestamp in the postgresql adapter. So, instead of having to incorrectly specify the precision using the <tt>:limit</tt> option, you may use <tt>:precision</tt>, as intended. For example, in a migration:

<ruby>
def change
  create_table :foobars do |t|
    t.timestamps :precision => 0
  end
end
</ruby>

* Allow <tt>ActiveRecord::Relation#pluck</tt> to accept multiple columns. Returns an array of arrays containing the typecasted values:

<ruby>
Person.pluck(:id, :name)
# SELECT people.id, people.name FROM people
# => [[1, 'David'], [2, 'Jeremy'], [3, 'Jose']]
</ruby>

* Improve the derivation of HABTM join table name to take account of nesting. It now takes the table names of the two models, sorts them lexically and then joins them, stripping any common prefix from the second table name. Some examples:

<plain>
Top level models (Category <=> Product)
Old: categories_products
New: categories_products

Top level models with a global table_name_prefix (Category <=> Product)
Old: site_categories_products
New: site_categories_products

Nested models in a module without a table_name_prefix method (Admin::Category <=> Admin::Product)
Old: categories_products
New: categories_products

Nested models in a module with a table_name_prefix method (Admin::Category <=> Admin::Product)
Old: categories_products
New: admin_categories_products

Nested models in a parent model (Catalog::Category <=> Catalog::Product)
Old: categories_products
New: catalog_categories_products

Nested models in different parent models (Catalog::Category <=> Content::Page)
Old: categories_pages
New: catalog_categories_content_pages
</plain>

* Move HABTM validity checks to <tt>ActiveRecord::Reflection</tt>. One side effect of this is to move when the exceptions are raised from the point of declaration to when the association is built. This is consistant with other association validity checks.

* Added <tt>stored_attributes</tt> hash which contains the attributes stored using <tt>ActiveRecord::Store</tt>. This allows you to retrieve the list of attributes you've defined.

<ruby>
class User < ActiveRecord::Base
  store :settings, accessors: [:color, :homepage]
end

User.stored_attributes[:settings] # [:color, :homepage]
</ruby>

* PostgreSQL default log level is now 'warning', to bypass the noisy notice messages. You can change the log level using the <tt>min_messages</tt> option available in your <tt>config/database.yml</tt>.

* Add uuid datatype support to PostgreSQL adapter.

* Added <tt>ActiveRecord::Migration.check_pending!</tt> that raises an error if migrations are pending.

* Added <tt>#destroy!</tt> which acts like <tt>#destroy</tt> but will raise an <tt>ActiveRecord::RecordNotDestroyed</tt> exception instead of returning <tt>false</tt>.

* Allow blocks for count with <tt>ActiveRecord::Relation</tt>, to work similar as <tt>Array#count</tt>: <tt>Person.where("age > 26").count { |person| person.gender == 'female' }</tt>

* Added support to <tt>CollectionAssociation#delete</tt> for passing fixnum or string values as record ids. This finds the records responding to the ids and deletes them.

<ruby>
class Person < ActiveRecord::Base
  has_many :pets
end

person.pets.delete("1")  # => [#<Pet id: 1>]
person.pets.delete(2, 3) # => [#<Pet id: 2>, #<Pet id: 3>]
</ruby>

* It's not possible anymore to destroy a model marked as read only.

* Added ability to <tt>ActiveRecord::Relation#from</tt> to accept other <tt>ActiveRecord::Relation</tt> objects.

* Added custom coders support for <tt>ActiveRecord::Store</tt>. Now you can set your custom coder like this:

<ruby>store :settings, accessors: [ :color, :homepage ], coder: JSON</ruby>

* +mysql+ and +mysql2+ connections will set <tt>SQL_MODE=STRICT_ALL_TABLES</tt> by default to avoid silent data loss. This can be disabled by specifying <tt>strict: false</tt> in <tt>config/database.yml</tt>.

* Added default order to <tt>ActiveRecord::Base#first</tt> to assure consistent results among diferent database engines. Introduced <tt>ActiveRecord::Base#take</tt> as a replacement to the old behavior.

* Added an <tt>:index</tt> option to automatically create indexes for +references+ and +belongs_to+ statements in migrations. This can be either a boolean or a hash that is identical to options available to the +add_index+ method:

<ruby>
create_table :messages do |t|
  t.references :person, :index => true
end
</ruby>

Is the same as:

<ruby>
create_table :messages do |t|
  t.references :person
end
add_index :messages, :person_id
</ruby>

Generators have also been updated to use the new syntax.

* Added bang methods for mutating <tt>ActiveRecord::Relation</tt> objects. For example, while <tt>foo.where(:bar)</tt> will return a new object leaving foo unchanged, <tt>foo.where!(:bar)</tt> will mutate the foo object.

* Added <tt>#find_by</tt> and <tt>#find_by!</tt> to mirror the functionality provided by dynamic finders in a way that allows dynamic input more easily:

<ruby>
Post.find_by name: 'Spartacus', rating: 4
Post.find_by "published_at < ?", 2.weeks.ago
Post.find_by! name: 'Spartacus'
</ruby>

* Added <tt>ActiveRecord::Base#slice</tt> to return a hash of the given methods with their names as keys and returned values as values.

* Remove IdentityMap - IdentityMap has never graduated to be an "enabled-by-default" feature, due to some inconsistencies with associations, as described in this "commit":https://github.com/rails/rails/commit/302c912bf6bcd0fa200d964ec2dc4a44abe328a6. Hence the removal from the codebase, until such issues are fixed.

* Added a feature to dump/load internal state of +SchemaCache+ instance because we want to boot more quickly when we have many models.

<ruby>
# execute rake task.
RAILS_ENV=production bundle exec rake db:schema:cache:dump
=> generate db/schema_cache.dump

# add config.use_schema_cache_dump = true in config/production.rb. BTW, true is default.

# boot rails.
RAILS_ENV=production bundle exec rails server
=> use db/schema_cache.dump

# If you remove clear dumped cache, execute rake task.
RAILS_ENV=production bundle exec rake db:schema:cache:clear
=> remove db/schema_cache.dump
</ruby>

* Added support for partial indices to +PostgreSQL+ adapter.

* The +add_index+ method now supports a +where+ option that receives a string with the partial index criteria.

* Added the <tt>ActiveRecord::NullRelation</tt> class implementing the null object pattern for the Relation class.

* Implemented <tt>ActiveRecord::Relation#none</tt> method which returns a chainable relation with zero records (an instance of the +NullRelation+ class). Any subsequent condition chained to the returned relation will continue generating an empty relation and will not fire any query to the database.

* Added +create_join_table+ migration helper to create HABTM join tables.

<ruby>
create_join_table :products, :categories
# =>
# create_table :categories_products, :id => false do |td|
#   td.integer :product_id, :null => false
#   td.integer :category_id, :null => false
# end
</ruby>

* The primary key is always initialized in the +@attributes+ hash to nil (unless another value has been specified).

* In previous releases, the following would generate a single query with an OUTER JOIN comments, rather than two separate queries:

<ruby>Post.includes(:comments).where("comments.name = 'foo'")</ruby>

This behaviour relies on matching SQL string, which is an inherently flawed idea unless we write an SQL parser, which we do not wish to do. Therefore, it is now deprecated.

To avoid deprecation warnings and for future compatibility, you must explicitly state which tables you reference, when using SQL snippets:

<ruby>Post.includes(:comments).where("comments.name = 'foo'").references(:comments)</ruby>

Note that you do not need to explicitly specify references in the following cases, as they can be automatically inferred:

<ruby>
Post.where(comments: { name: 'foo' })
Post.where('comments.name' => 'foo')
Post.order('comments.name')
</ruby>

You also do not need to worry about this unless you are doing eager loading. Basically, don't worry unless you see a deprecation warning or (in future releases) an SQL error due to a missing JOIN.

* Support for the +schema_info+ table has been dropped. Please switch to +schema_migrations+.

* Connections *must* be closed at the end of a thread. If not, your connection pool can fill and an exception will be raised.

* Added the <tt>ActiveRecord::Model</tt> module which can be included in a class as an alternative to inheriting from <tt>ActiveRecord::Base</tt>:

<ruby>
class Post
  include ActiveRecord::Model
end
</ruby>

* PostgreSQL hstore records can be created.

* PostgreSQL hstore types are automatically deserialized from the database.

h4(#activerecord_deprecations). Deprecations

* Deprecated most of the 'dynamic finder' methods. All dynamic methods except for +find_by_...+ and +find_by_...!+ are deprecated. Here's how you can rewrite the code:

<ruby>
find_all_by_... can be rewritten using where(...)
find_last_by_... can be rewritten using where(...).last
scoped_by_... can be rewritten using where(...)
find_or_initialize_by_... can be rewritten using where(...).first_or_initialize
find_or_create_by_... can be rewritten using where(...).first_or_create
find_or_create_by_...! can be rewritten using where(...).first_or_create!
</ruby>

The implementation of the deprecated dynamic finders has been moved to the +active_record_deprecated_finders+ gem.

* Deprecated the old-style hash based finder API. This means that methods which previously accepted "finder options" no longer do. For example this:

<ruby>Post.find(:all, :conditions => { :comments_count => 10 }, :limit => 5)</ruby>

should be rewritten in the new style which has existed since Rails 3:

<ruby>Post.where(comments_count: 10).limit(5)</ruby>

Note that as an interim step, it is possible to rewrite the above as:

<ruby>Post.scoped(:where => { :comments_count => 10 }, :limit => 5)</ruby>

This could save you a lot of work if there is a lot of old-style finder usage in your application.

Calling <tt>Post.scoped(options)</tt> is a shortcut for <tt>Post.scoped.merge(options)</tt>. <tt>Relation#merge</tt> now accepts a hash of options, but they must be identical to the names of the equivalent finder method. These are mostly identical to the old-style finder option names, except in the following cases:

<plain>
:conditions becomes :where
:include becomes :includes
:extend becomes :extending
</plain>

The code to implement the deprecated features has been moved out to the +active_record_deprecated_finders+ gem. This gem is a dependency of Active Record in Rails 4.0. It will no longer be a dependency from Rails 4.1, but if your app relies on the deprecated features then you can add it to your own Gemfile. It will be maintained by the Rails core team until Rails 5.0 is released.

* Deprecate eager-evaluated scopes.

  Don't use this:

<ruby>
scope :red, where(color: 'red')
default_scope where(color: 'red')
</ruby>

  Use this:

<ruby>
scope :red, -> { where(color: 'red') }
default_scope { where(color: 'red') }
</ruby>

  The former has numerous issues. It is a common newbie gotcha to do the following:

<ruby>
scope :recent, where(published_at: Time.now - 2.weeks)
</ruby>

  Or a more subtle variant:

<ruby>
scope :recent, -> { where(published_at: Time.now - 2.weeks) }
scope :recent_red, recent.where(color: 'red')
</ruby>

  Eager scopes are also very complex to implement within Active Record, and there are still bugs. For example, the following does not do what you expect:

<ruby>
scope :remove_conditions, except(:where)
where(...).remove_conditions # => still has conditions
</ruby>

* Added deprecation for the :dependent => :restrict association option.

* Up until now has_many and has_one, :dependent => :restrict option raised a DeleteRestrictionError at the time of destroying the object. Instead, it will add an error on the model.

* To fix this warning, make sure your code isn't relying on a DeleteRestrictionError and then add config.active_record.dependent_restrict_raises = false to your application config.

* New rails application would be generated with the config.active_record.dependent_restrict_raises = false in the application config.

* The migration generator now creates a join table with (commented) indexes every time the migration name contains the word "join_table".

* <tt>ActiveRecord::SessionStore</tt> is removed from Rails 4.0 and is now a separate "gem":https://github.com/rails/activerecord-session_store.

h3. Active Model

* Changed <tt>AM::Serializers::JSON.include_root_in_json</tt> default value to false. Now, AM Serializers and AR objects have the same default behaviour.

<ruby>
class User < ActiveRecord::Base; end

class Person
  include ActiveModel::Model
  include ActiveModel::AttributeMethods
  include ActiveModel::Serializers::JSON

  attr_accessor :name, :age

  def attributes
    instance_values
  end
end

user.as_json
=> {"id"=>1, "name"=>"Konata Izumi", "age"=>16, "awesome"=>true}
# root is not included

person.as_json
=> {"name"=>"Francesco", "age"=>22}
# root is not included
</ruby>

* Passing false hash values to +validates+ will no longer enable the corresponding validators.

* +ConfirmationValidator+ error messages will attach to <tt>:#{attribute}_confirmation</tt> instead of +attribute+.

* Added <tt>ActiveModel::Model</tt>, a mixin to make Ruby objects work with Action Pack out of the box.

* <tt>ActiveModel::Errors#to_json</tt> supports a new parameter <tt>:full_messages</tt>.

* Trims down the API by removing <tt>valid?</tt> and <tt>errors.full_messages</tt>.

h4(#activemodel_deprecations). Deprecations

h3. Active Resource

* Active Resource is removed from Rails 4.0 and is now a separate "gem":https://github.com/rails/activeresource.

h3. Active Support

* Add default values to all <tt>ActiveSupport::NumberHelper</tt> methods, to avoid errors with empty locales or missing values.

* <tt>Time#change</tt> now works with time values with offsets other than UTC or the local time zone.

* Add <tt>Time#prev_quarter</tt> and <tt>Time#next_quarter</tt> short-hands for <tt>months_ago(3)</tt> and <tt>months_since(3)</tt>.

* Remove obsolete and unused <tt>require_association</tt> method from dependencies.

* Add <tt>:instance_accessor</tt> option for <tt>config_accessor</tt>.

<ruby>
class User
  include ActiveSupport::Configurable
  config_accessor :allowed_access, instance_accessor: false
end

User.new.allowed_access = true # => NoMethodError
User.new.allowed_access        # => NoMethodError
</ruby>

* <tt>ActionView::Helpers::NumberHelper</tt> methods have been moved to <tt>ActiveSupport::NumberHelper</tt> and are now available via <tt>Numeric#to_s</tt>.

* <tt>Numeric#to_s</tt> now accepts the formatting options :phone, :currency, :percentage, :delimited, :rounded, :human, and :human_size.

* Add <tt>Hash#transform_keys</tt>, <tt>Hash#transform_keys!</tt>, <tt>Hash#deep_transform_keys</tt> and <tt>Hash#deep_transform_keys!</tt>.

* Changed xml type datetime to dateTime (with upper case letter T).

* Add <tt>:instance_accessor</tt> option for <tt>class_attribute</tt>.

* +constantize+ now looks in the ancestor chain.

* Add <tt>Hash#deep_stringify_keys</tt> and <tt>Hash#deep_stringify_keys!</tt> to convert all keys from a +Hash+ instance into strings.

* Add <tt>Hash#deep_symbolize_keys</tt> and <tt>Hash#deep_symbolize_keys!</tt> to convert all keys from a +Hash+ instance into symbols.

* <tt>Object#try</tt> can't call private methods.

* AS::Callbacks#run_callbacks remove key argument.

* +deep_dup+ works more expectedly now and duplicates also values in +Hash+ instances and elements in +Array+ instances.

* Inflector no longer applies ice -> ouse to words like slice, police.

* Add <tt>ActiveSupport::Deprecations.behavior = :silence</tt> to completely ignore Rails runtime deprecations.

* Make <tt>Module#delegate</tt> stop using send - can no longer delegate to private methods.

* AS::Callbacks deprecate :rescuable option.

* Adds <tt>Integer#ordinal</tt> to get the ordinal suffix string of an integer.

* AS::Callbacks :per_key option is no longer supported.

* AS::Callbacks#define_callbacks add :skip_after_callbacks_if_terminated option.

* Add html_escape_once to ERB::Util, and delegate escape_once tag helper to it.

* Remove <tt>ActiveSupport::TestCase#pending</tt> method, use +skip+ instead.

* Deletes the compatibility method <tt>Module#method_names</tt>, use <tt>Module#methods</tt> from now on (which returns symbols).

* Deletes the compatibility method <tt>Module#instance_method_names</tt>, use <tt>Module#instance_methods</tt> from now on (which returns symbols).

* Unicode database updated to 6.1.0.

* Adds +encode_big_decimal_as_string+ option to force JSON serialization of BigDecimals as numeric instead of wrapping them in strings for safety.

h4(#activesupport_deprecations). Deprecations

* <tt>ActiveSupport::Callbacks</tt>: deprecate usage of filter object with <tt>#before</tt> and <tt>#after</tt> methods as <tt>around</tt> callback.

* <tt>BufferedLogger</tt> is deprecated.  Use <tt>ActiveSupport::Logger</tt> or the +logger+ from Ruby stdlib.

* Deprecates the compatibility method <tt>Module#local_constant_names</tt> and use <tt>Module#local_constants</tt> instead (which returns symbols).

h3. Credits

See the "full list of contributors to Rails":http://contributors.rubyonrails.org/ for the many people who spent many hours making Rails, the stable and robust framework it is. Kudos to all of them.
