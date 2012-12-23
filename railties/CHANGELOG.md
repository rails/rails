## Rails 3.1.9

## Rails 3.1.8 (Aug 9, 2012)

*   No changes.

## Rails 3.1.7 (Jul 26, 2012)

*   No changes.

## Rails 3.1.6 (Jun 12, 2012)

*   No changes.

## Rails 3.1.5 (May 31, 2012) ##

*   No changes.

## Rails 3.1.4 (unreleased) ##

*   Setting config.force_ssl also marks the session cookie as secure.

    *José Valim*

*   Add therubyrhino to Gemfile in new applications when running under JRuby.

    *Guillermo Iguaran*


## Rails 3.1.3 (November 20, 2011) ##

*   New apps should be generated with a sass-rails dependency of 3.1.5, not 3.1.5.rc.2


## Rails 3.1.2 (November 18, 2011) ##

*   Engines: don't blow up if db/seeds.rb is missing.

    *Jeremy Kemper*

*   `rails new foo --skip-test-unit` should not add the `:test` task to the rake default task.
    *GH 2564*

    *José Valim*


## Rails 3.1.1 (October 7, 2011) ##

*   Add jquery-rails to Gemfile of plugins, test/dummy app needs it. Closes #3091. *Santiago Pastorino*

*   Add config.assets.initialize_on_precompile which, when set to false, forces
    `rake assets:precompile` to load the application but does not initialize it.

    To the app developer, this means configuration add in
    config/initializers/* will not be executed.

    Plugins developers need to special case their initializers that are
    meant to be run in the assets group by adding :group => :assets.

    *José Valim*


## Rails 3.1.0 (August 30, 2011) ##

*   The default database schema file is written as UTF-8. *Aaron Patterson*

*   Generated apps with --dev or --edge flags depend on git versions of
    sass-rails and coffee-rails. *Santiago Pastorino*

*   Rack::Sendfile middleware is used only if x_sendfile_header is present. *Santiago Pastorino*

*   Add JavaScript Runtime name to the Rails Info properties. *DHH*

*   Make pp enabled by default in Rails console. *Akira Matsuda*

*   Add alias `r` for rails runner. *Jordi Romero*

*   Make sprockets/railtie require explicit and add --skip-sprockets to app generator *José Valim*

*   Added Rails.groups that automatically handles Rails.env and ENV["RAILS_GROUPS"] *José Valim*

*   The new rake task assets:clean removes precompiled assets. *fxn*

*   Application and plugin generation run bundle install unless --skip-gemfile or --skip-bundle. *fxn*

*   Fixed database tasks for jdbc* adapters #jruby *Rashmi Yadav*

*   Template generation for jdbcpostgresql  #jruby *Vishnu Atrai*

*   Template generation for jdbcmysql and jdbcsqlite3 #jruby *Arun Agrawal*

*   The -j option of the application generator accepts an arbitrary string. If passed "foo",
    the gem "foo-rails" is added to the Gemfile, and the application JavaScript manifest
    requires "foo" and "foo_ujs". As of this writing "prototype-rails" and "jquery-rails"
    exist and provide those files via the asset pipeline. Default is "jquery". *fxn*

*   jQuery is no longer vendored, it is provided from now on by the jquery-rails gem. *fxn*

*   Prototype and Scriptaculous are no longer vendored, they are provided from now on
    by the prototype-rails gem. *fxn*

*   The scaffold controller will now produce SCSS file if Sass is available *Prem Sichanugrist*

*   The controller and resource generators will now automatically produce asset stubs (this can be turned off with --skip-assets). These stubs will use Coffee and Sass, if those libraries are available. *DHH*

*   jQuery is the new default JavaScript library. *fxn*

*   Changed scaffold, application, and mailer generator to create Ruby 1.9 style hash when running on Ruby 1.9 *Prem Sichanugrist*

    So instead of creating something like:

        redirect_to users_path, :notice => "User has been created"

    it will now be like this:

        redirect_to users_path, notice: "User has been created"

    You can also passing `--old-style-hash` to make Rails generate old style hash even you're on Ruby 1.9

*   Changed scaffold_controller generator to create format block for JSON instead of XML *Prem Sichanugrist*

*   Add using Turn with natural language test case names for test_help.rb when running with minitest (Ruby 1.9.2+) *DHH*

*   Direct logging of Active Record to STDOUT so it's shown inline with the results in the console *DHH*

*   Added `config.force_ssl` configuration which loads Rack::SSL middleware and force all requests to be under HTTPS protocol *DHH, Prem Sichanugrist, and Josh Peek*

*   Added `rails plugin new` command which generates rails plugin with gemspec, tests and dummy application for testing *Piotr Sarnacki*

*   Added -j parameter with jquery/prototype as options. Now you can create your apps with jQuery using `rails new myapp -j jquery`. The default is still Prototype. *siong1987*

*   Added Rack::Etag and Rack::ConditionalGet to the default middleware stack *José Valim*

*   Added Rack::Cache to the default middleware stack *Yehuda Katz and Carl Lerche*

*   Engine is now rack application *Piotr Sarnacki*

*   Added middleware stack to Engine *Piotr Sarnacki*

*   Engine can now load plugins *Piotr Sarnacki*

*   Engine can load its own environment file *Piotr Sarnacki*

*   Added helpers to call engines' route helpers from application and vice versa *Piotr Sarnacki*

*   Task for copying plugins' and engines' migrations to application's db/migrate directory *Piotr Sarnacki*

*   Changed ActionDispatch::Static to allow handling multiple directories *Piotr Sarnacki*

*   Added isolate_namespace() method to Engine, which sets Engine as isolated *Piotr Sarnacki*

*   Include all helpers from plugins and shared engines in application *Piotr Sarnacki*

Please check [3-0-stable](https://github.com/rails/rails/blob/3-0-stable/railties/CHANGELOG) for previous changes.
