**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Configuring Rails Applications
==============================

This guide covers the configuration and initialization features available to Rails applications.

After reading this guide, you will know:

* How to adjust the behavior of your Rails applications.
* How to add additional code to be run at application start time.

--------------------------------------------------------------------------------

Locations for Initialization Code
---------------------------------

Rails offers four standard spots to place initialization code:

* `config/application.rb`
* Environment-specific configuration files
* Initializers
* After-initializers

Running Code Before Rails
-------------------------

In the rare event that your application needs to run some code before Rails itself is loaded, put it above the call to `require "rails/all"` in `config/application.rb`.

Configuring Rails Components
----------------------------

In general, the work of configuring Rails means configuring the components of Rails, as well as configuring Rails itself. The configuration file `config/application.rb` and environment-specific configuration files (such as `config/environments/production.rb`) allow you to specify the various settings that you want to pass down to all of the components.

For example, you could add this setting to `config/application.rb` file:

```ruby
config.time_zone = 'Central Time (US & Canada)'
```

This is a setting for Rails itself. If you want to pass settings to individual Rails components, you can do so via the same `config` object in `config/application.rb`:

```ruby
config.active_record.schema_format = :ruby
```

Rails will use that particular setting to configure Active Record.

WARNING: Use the public configuration methods over calling directly to the associated class. e.g. `Rails.application.config.action_mailer.options` instead of `ActionMailer::Base.options`.

NOTE: If you need to apply configuration directly to a class, use a [lazy load hook](https://api.rubyonrails.org/classes/ActiveSupport/LazyLoadHooks.html) in an initializer to avoid autoloading the class before initialization has completed. This will break because autoloading during initialization cannot be safely repeated when the app reloads.

### Versioned Default Values

[`config.load_defaults`] loads default configuration values for a target version and all versions prior. For example, `config.load_defaults 6.1` will load defaults for all versions up to and including version 6.1.

[`config.load_defaults`]: https://api.rubyonrails.org/classes/Rails/Application/Configuration.html#method-i-load_defaults

Below are the default values associated with each target version. In cases of conflicting values, newer versions take precedence over older versions.

#### Default Values for Target Version 7.1

- [`config.action_controller.allow_deprecated_parameters_hash_equality`](#config-action-controller-allow-deprecated-parameters-hash-equality): `false`
- [`config.action_dispatch.default_headers`](#config-action-dispatch-default-headers): `{ "X-Frame-Options" => "SAMEORIGIN", "X-XSS-Protection" => "0", "X-Content-Type-Options" => "nosniff", "X-Permitted-Cross-Domain-Policies" => "none", "Referrer-Policy" => "strict-origin-when-cross-origin" }`
- [`config.active_job.use_big_decimal_serializer`](#config-active-job-use-big-decimal-serializer): `true`
- [`config.active_record.allow_deprecated_singular_associations_name`](#config-active-record-allow-deprecated-singular-associations-name): `false`
- [`config.active_record.query_log_tags_format`](#config-active-record-query-log-tags-format): `:sqlcommenter`
- [`config.active_record.raise_on_assign_to_attr_readonly`](#config-active-record-raise-on-assign-to-attr-readonly): `true`
- [`config.active_record.belongs_to_required_validates_foreign_key`](#config-active-record-belongs-to-required-validates-foreign-key): `false`
- [`config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction`](#config-active-record-run-commit-callbacks-on-first-saved-instances-in-transaction): `false`
- [`config.active_record.sqlite3_adapter_strict_strings_by_default`](#config-active-record-sqlite3-adapter-strict-strings-by-default): `true`
- [`config.active_support.default_message_encryptor_serializer`](#config-active-support-default-message-encryptor-serializer): `:json`
- [`config.active_support.default_message_verifier_serializer`](#config-active-support-default-message-verifier-serializer): `:json`
- [`config.active_support.raise_on_invalid_cache_expiration_time`](#config-active-support-raise-on-invalid-cache-expiration-time): `true`
- [`config.add_autoload_paths_to_load_path`](#config-add-autoload-paths-to-load-path): `false`
- [`config.log_file_size`](#config-log-file-size): `100 * 1024 * 1024`
- [`config.precompile_filter_parameters`](#config-precompile-filter-parameters): `true`

#### Default Values for Target Version 7.0

- [`config.action_controller.raise_on_open_redirects`](#config-action-controller-raise-on-open-redirects): `true`
- [`config.action_controller.wrap_parameters_by_default`](#config-action-controller-wrap-parameters-by-default): `true`
- [`config.action_dispatch.cookies_serializer`](#config-action-dispatch-cookies-serializer): `:json`
- [`config.action_dispatch.default_headers`](#config-action-dispatch-default-headers): `{ "X-Frame-Options" => "SAMEORIGIN", "X-XSS-Protection" => "0", "X-Content-Type-Options" => "nosniff", "X-Download-Options" => "noopen", "X-Permitted-Cross-Domain-Policies" => "none", "Referrer-Policy" => "strict-origin-when-cross-origin" }`
- [`config.action_dispatch.return_only_request_media_type_on_content_type`](#config-action-dispatch-return-only-request-media-type-on-content-type): `false`
- [`config.action_mailer.smtp_timeout`](#config-action-mailer-smtp-timeout): `5`
- [`config.action_view.apply_stylesheet_media_default`](#config-action-view-apply-stylesheet-media-default): `false`
- [`config.action_view.button_to_generates_button_tag`](#config-action-view-button-to-generates-button-tag): `true`
- [`config.active_record.automatic_scope_inversing`](#config-active-record-automatic-scope-inversing): `true`
- [`config.active_record.partial_inserts`](#config-active-record-partial-inserts): `false`
- [`config.active_record.verify_foreign_keys_for_fixtures`](#config-active-record-verify-foreign-keys-for-fixtures): `true`
- [`config.active_storage.multiple_file_field_include_hidden`](#config-active-storage-multiple-file-field-include-hidden): `true`
- [`config.active_storage.variant_processor`](#config-active-storage-variant-processor): `:vips`
- [`config.active_storage.video_preview_arguments`](#config-active-storage-video-preview-arguments): `"-vf 'select=eq(n\\,0)+eq(key\\,1)+gt(scene\\,0.015),loop=loop=-1:size=2,trim=start_frame=1' -frames:v 1 -f image2"`
- [`config.active_support.cache_format_version`](#config-active-support-cache-format-version): `7.0`
- [`config.active_support.disable_to_s_conversion`](#config-active-support-disable-to-s-conversion): `true`
- [`config.active_support.executor_around_test_case`](#config-active-support-executor-around-test-case): `true`
- [`config.active_support.hash_digest_class`](#config-active-support-hash-digest-class): `OpenSSL::Digest::SHA256`
- [`config.active_support.isolation_level`](#config-active-support-isolation-level): `:thread`
- [`config.active_support.key_generator_hash_digest_class`](#config-active-support-key-generator-hash-digest-class): `OpenSSL::Digest::SHA256`
- [`config.active_support.remove_deprecated_time_with_zone_name`](#config-active-support-remove-deprecated-time-with-zone-name): `true`
- [`config.active_support.use_rfc4122_namespaced_uuids`](#config-active-support-use-rfc4122-namespaced-uuids): `true`

#### Default Values for Target Version 6.1

- [`ActiveSupport.utc_to_local_returns_utc_offset_times`](#activesupport-utc-to-local-returns-utc-offset-times): `true`
- [`config.action_dispatch.cookies_same_site_protection`](#config-action-dispatch-cookies-same-site-protection): `:lax`
- [`config.action_dispatch.ssl_default_redirect_status`](#config-action-dispatch-ssl-default-redirect-status): `308`
- [`config.action_mailbox.queues.incineration`](#config-action-mailbox-queues-incineration): `nil`
- [`config.action_mailbox.queues.routing`](#config-action-mailbox-queues-routing): `nil`
- [`config.action_mailer.deliver_later_queue_name`](#config-action-mailer-deliver-later-queue-name): `nil`
- [`config.action_view.form_with_generates_remote_forms`](#config-action-view-form-with-generates-remote-forms): `false`
- [`config.action_view.preload_links_header`](#config-action-view-preload-links-header): `true`
- [`config.active_job.retry_jitter`](#config-active-job-retry-jitter): `0.15`
- [`config.active_record.has_many_inversing`](#config-active-record-has-many-inversing): `true`
- [`config.active_storage.queues.analysis`](#config-active-storage-queues-analysis): `nil`
- [`config.active_storage.queues.purge`](#config-active-storage-queues-purge): `nil`
- [`config.active_storage.track_variants`](#config-active-storage-track-variants): `true`

#### Default Values for Target Version 6.0

- [`config.action_dispatch.use_cookies_with_metadata`](#config-action-dispatch-use-cookies-with-metadata): `true`
- [`config.action_mailer.delivery_job`](#config-action-mailer-delivery-job): `"ActionMailer::MailDeliveryJob"`
- [`config.action_view.default_enforce_utf8`](#config-action-view-default-enforce-utf8): `false`
- [`config.active_record.collection_cache_versioning`](#config-active-record-collection-cache-versioning): `true`
- [`config.active_storage.queues.analysis`](#config-active-storage-queues-analysis): `:active_storage_analysis`
- [`config.active_storage.queues.purge`](#config-active-storage-queues-purge): `:active_storage_purge`
- [`config.active_storage.replace_on_assign_to_many`](#config-active-storage-replace-on-assign-to-many): `true`

#### Default Values for Target Version 5.2

- [`config.action_controller.default_protect_from_forgery`](#config-action-controller-default-protect-from-forgery): `true`
- [`config.action_dispatch.use_authenticated_cookie_encryption`](#config-action-dispatch-use-authenticated-cookie-encryption): `true`
- [`config.action_view.form_with_generates_ids`](#config-action-view-form-with-generates-ids): `true`
- [`config.active_record.cache_versioning`](#config-active-record-cache-versioning): `true`
- [`config.active_support.hash_digest_class`](#config-active-support-hash-digest-class): `OpenSSL::Digest::SHA1`
- [`config.active_support.use_authenticated_message_encryption`](#config-active-support-use-authenticated-message-encryption): `true`

#### Default Values for Target Version 5.1

- [`config.action_view.form_with_generates_remote_forms`](#config-action-view-form-with-generates-remote-forms): `true`
- [`config.assets.unknown_asset_fallback`](#config-assets-unknown-asset-fallback): `false`

#### Default Values for Target Version 5.0

- [`ActiveSupport.to_time_preserves_timezone`](#activesupport-to-time-preserves-timezone): `true`
- [`config.action_controller.forgery_protection_origin_check`](#config-action-controller-forgery-protection-origin-check): `true`
- [`config.action_controller.per_form_csrf_tokens`](#config-action-controller-per-form-csrf-tokens): `true`
- [`config.active_record.belongs_to_required_by_default`](#config-active-record-belongs-to-required-by-default): `true`
- [`config.ssl_options`](#config-ssl-options): `{ hsts: { subdomains: true } }`

### Rails General Configuration

The following configuration methods are to be called on a `Rails::Railtie` object, such as a subclass of `Rails::Engine` or `Rails::Application`.

#### `config.add_autoload_paths_to_load_path`

Says whether autoload paths have to be added to `$LOAD_PATH`. It is recommended to be set to `false` in `:zeitwerk` mode early, in `config/application.rb`. Zeitwerk uses absolute paths internally, and applications running in `:zeitwerk` mode do not need `require_dependency`, so models, controllers, jobs, etc. do not need to be in `$LOAD_PATH`. Setting this to `false` saves Ruby from checking these directories when resolving `require` calls with relative paths, and saves Bootsnap work and RAM, since it does not need to build an index for them.

The default value depends on the `config.load_defaults` target version:

| Starting with version | The default value is |
| --------------------- | -------------------- |
| (original)            | `true`               |
| 7.1                   | `false`              |

#### `config.after_initialize`

Takes a block which will be run _after_ Rails has finished initializing the application. That includes the initialization of the framework itself, engines, and all the application's initializers in `config/initializers`. Note that this block _will_ be run for rake tasks. Useful for configuring values set up by other initializers:

```ruby
config.after_initialize do
  ActionView::Base.sanitized_allowed_tags.delete 'div'
end
```

### `config.after_routes_loaded`

Takes a block which will be run after Rails has finished loading the application routes. This block will also be run whenever routes are reloaded.

```ruby
config.after_routes_loaded do
  # Code that does something with Rails.application.routes
end
```

#### `config.allow_concurrency`

Controls whether requests should be handled concurrently. This should only
be set to `false` if application code is not thread safe. Defaults to `true`.

#### `config.asset_host`

Sets the host for the assets. Useful when CDNs are used for hosting assets, or when you want to work around the concurrency constraints built-in in browsers using different domain aliases. Shorter version of `config.action_controller.asset_host`.

#### `config.autoflush_log`

Enables writing log file output immediately instead of buffering. Defaults to
`true`.

#### `config.autoload_once_paths`

Accepts an array of paths from which Rails will autoload constants that won't be wiped per request. Relevant if reloading is enabled, which it is by default in the `development` environment. Otherwise, all autoloading happens only once. All elements of this array must also be in `autoload_paths`. Default is an empty array.

#### `config.autoload_paths`

Accepts an array of paths from which Rails will autoload constants. Default is an empty array. Since [Rails 6](upgrading_ruby_on_rails.html#autoloading), it is not recommended to adjust this. See [Autoloading and Reloading Constants](autoloading_and_reloading_constants.html#autoload-paths).

#### `config.beginning_of_week`

Sets the default beginning of week for the
application. Accepts a valid day of week as a symbol (e.g. `:monday`).

#### `config.cache_classes`

Old setting equivalent to `!config.enable_reloading`. Supported for backwards compatibility.

#### `config.cache_store`

Configures which cache store to use for Rails caching. Options include one of the symbols `:memory_store`, `:file_store`, `:mem_cache_store`, `:null_store`, `:redis_cache_store`, or an object that implements the cache API. Defaults to `:file_store`. See [Cache Stores](caching_with_rails.html#cache-stores) for per-store configuration options.

#### `config.colorize_logging`

Specifies whether or not to use ANSI color codes when logging information. Defaults to `true`.

#### `config.consider_all_requests_local`

Is a flag. If `true` then any error will cause detailed debugging information to be dumped in the HTTP response, and the `Rails::Info` controller will show the application runtime context in `/rails/info/properties`. `true` by default in the development and test environments, and `false` in production. For finer-grained control, set this to `false` and implement `show_detailed_exceptions?` in controllers to specify which requests should provide debugging information on errors.

#### `config.console`

Allows you to set the class that will be used as console when you run `bin/rails console`. It's best to run it in the `console` block:

```ruby
console do
  # this block is called only when running console,
  # so we can safely require pry here
  require "pry"
  config.console = Pry
end
```

#### `config.content_security_policy_nonce_directives`

See [Adding a Nonce](security.html#adding-a-nonce) in the Security Guide

#### `config.content_security_policy_nonce_generator`

See [Adding a Nonce](security.html#adding-a-nonce) in the Security Guide

#### `config.content_security_policy_report_only`

See [Reporting Violations](security.html#reporting-violations) in the Security
Guide

#### `config.credentials.content_path`

Configures lookup path for encrypted credentials.

#### `config.credentials.key_path`

Configures lookup path for encryption key.

#### `config.debug_exception_response_format`

Sets the format used in responses when errors occur in the development environment. Defaults to `:api` for API only apps and `:default` for normal apps.

#### `config.disable_sandbox`

Controls whether or not someone can start a console in sandbox mode. This is helpful to avoid a long running session of sandbox console, that could lead a database server to run out of memory. Defaults to `false`.

#### `config.eager_load`

When `true`, eager loads all registered `config.eager_load_namespaces`. This includes your application, engines, Rails frameworks, and any other registered namespace.

#### `config.eager_load_namespaces`

Registers namespaces that are eager loaded when `config.eager_load` is set to `true`. All namespaces in the list must respond to the `eager_load!` method.

#### `config.eager_load_paths`

Accepts an array of paths from which Rails will eager load on boot if `config.eager_load` is true. Defaults to every folder in the `app` directory of the application.

#### `config.enable_reloading`

If `config.enable_reloading` is true, application classes and modules are reloaded in between web requests if they change. Defaults to `true` in the `development` environment, and `false` in the `production` environment.

The predicate `config.reloading_enabled?` is also defined.

#### `config.encoding`

Sets up the application-wide encoding. Defaults to UTF-8.

#### `config.exceptions_app`

Sets the exceptions application invoked by the `ShowException` middleware when an exception happens. Defaults to `ActionDispatch::PublicExceptions.new(Rails.public_path)`.

#### `config.file_watcher`

Is the class used to detect file updates in the file system when `config.reload_classes_only_on_change` is `true`. Rails ships with `ActiveSupport::FileUpdateChecker`, the default, and `ActiveSupport::EventedFileUpdateChecker` (this one depends on the [listen](https://github.com/guard/listen) gem). Custom classes must conform to the `ActiveSupport::FileUpdateChecker` API.

#### `config.filter_parameters`

Used for filtering out the parameters that you don't want shown in the logs,
such as passwords or credit card numbers. It also filters out sensitive values
of database columns when calling `#inspect` on an Active Record object. By
default, Rails filters out passwords by adding the following filters in
`config/initializers/filter_parameter_logging.rb`.

```ruby
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn
]
```

Parameters filter works by partial matching regular expression.

#### `config.filter_redirect`

Used for filtering out redirect urls from application logs.

```ruby
Rails.application.config.filter_redirect += ['s3.amazonaws.com', /private-match/]
```

The redirect filter works by testing that urls include strings or match regular
expressions.

#### `config.force_ssl`

Forces all requests to be served over HTTPS, and sets "https://" as the default protocol when generating URLs. Enforcement of HTTPS is handled by the `ActionDispatch::SSL` middleware, which can be configured via `config.ssl_options`.

#### `config.helpers_paths`

Defines an array of additional paths to load view helpers.

#### `config.host_authorization`

Accepts a hash of options to configure the [HostAuthorization
middleware](#actiondispatch-hostauthorization)

#### `config.hosts`

An array of strings, regular expressions, or `IPAddr` used to validate the
`Host` header. Used by the [HostAuthorization
middleware](#actiondispatch-hostauthorization) to help prevent DNS rebinding
attacks.

#### `config.javascript_path`

Sets the path where your app's JavaScript lives relative to the `app` directory. The default is `javascript`, used by [webpacker](https://github.com/rails/webpacker). An app's configured `javascript_path` will be excluded from `autoload_paths`.

#### `config.log_file_size`

Defines the maximum size of the Rails log file in bytes. Defaults to `104_857_600` (100 MiB) in development and test, and unlimited in all other environments.

#### `config.log_formatter`

Defines the formatter of the Rails logger. This option defaults to an instance of `ActiveSupport::Logger::SimpleFormatter` for all environments. If you are setting a value for `config.logger` you must manually pass the value of your formatter to your logger before it is wrapped in an `ActiveSupport::TaggedLogging` instance, Rails will not do it for you.

#### `config.log_level`

Defines the verbosity of the Rails logger. This option defaults to `:debug` for all environments except production, where it defaults to `:info`. The available log levels are: `:debug`, `:info`, `:warn`, `:error`, `:fatal`, and `:unknown`.

#### `config.log_tags`

Accepts a list of methods that the `request` object responds to, a `Proc` that accepts the `request` object, or something that responds to `to_s`. This makes it easy to tag log lines with debug information like subdomain and request id - both very helpful in debugging multi-user production applications.

#### `config.logger`

Is the logger that will be used for `Rails.logger` and any related Rails logging such as `ActiveRecord::Base.logger`. It defaults to an instance of `ActiveSupport::TaggedLogging` that wraps an instance of `ActiveSupport::Logger` which outputs a log to the `log/` directory. You can supply a custom logger, to get full compatibility you must follow these guidelines:

* To support a formatter, you must manually assign a formatter from the `config.log_formatter` value to the logger.
* To support tagged logs, the log instance must be wrapped with `ActiveSupport::TaggedLogging`.
* To support silencing, the logger must include `ActiveSupport::LoggerSilence` module. The `ActiveSupport::Logger` class already includes these modules.

```ruby
class MyLogger < ::Logger
  include ActiveSupport::LoggerSilence
end

mylogger           = MyLogger.new(STDOUT)
mylogger.formatter = config.log_formatter
config.logger      = ActiveSupport::TaggedLogging.new(mylogger)
```

#### `config.middleware`

Allows you to configure the application's middleware. This is covered in depth in the [Configuring Middleware](#configuring-middleware) section below.

#### `config.precompile_filter_parameters`

When `true`, will precompile [`config.filter_parameters`](#config-filter-parameters)
using [`ActiveSupport::ParameterFilter.precompile_filters`][].

The default value depends on the `config.load_defaults` target version:

| Starting with version | The default value is |
| --------------------- | -------------------- |
| (original)            | `false`              |
| 7.1                   | `true`               |

[`ActiveSupport::ParameterFilter.precompile_filters`]: https://api.rubyonrails.org/classes/ActiveSupport/ParameterFilter.html#method-c-precompile_filters

#### `config.public_file_server.enabled`

Configures Rails to serve static files from the public directory. This option defaults to `true`, but in the production environment it is set to `false` because the server software (e.g. NGINX or Apache) used to run the application should serve static files instead. If you are running or testing your app in production using WEBrick (it is not recommended to use WEBrick in production), set the option to `true`. Otherwise, you won't be able to use page caching and request for files that exist under the public directory.

#### `config.railties_order`

Allows manually specifying the order that Railties/Engines are loaded. The
default value is `[:all]`.

```ruby
config.railties_order = [Blog::Engine, :main_app, :all]
```

#### `config.rake_eager_load`

When `true`, eager load the application when running Rake tasks. Defaults to `false`.

#### `config.read_encrypted_secrets`

*DEPRECATED*: You should be using
[credentials](https://guides.rubyonrails.org/security.html#custom-credentials)
instead of encrypted secrets.

When `true`, will try to read encrypted secrets from `config/secrets.yml.enc`

#### `config.relative_url_root`

Can be used to tell Rails that you are [deploying to a subdirectory](
configuring.html#deploy-to-a-subdirectory-relative-url-root). The default
is `ENV['RAILS_RELATIVE_URL_ROOT']`.

#### `config.reload_classes_only_on_change`

Enables or disables reloading of classes only when tracked files change. By default tracks everything on autoload paths and is set to `true`. If `config.enable_reloading` is `false`, this option is ignored.

#### `config.require_master_key`

Causes the app to not boot if a master key hasn't been made available through `ENV["RAILS_MASTER_KEY"]` or the `config/master.key` file.

#### `config.secret_key_base`

The fallback for specifying the input secret for an application's key generator.
It is recommended to leave this unset, and instead to specify a `secret_key_base`
in `config/credentials.yml.enc`. See the [`secret_key_base` API documentation](
https://api.rubyonrails.org/classes/Rails/Application.html#method-i-secret_key_base)
for more information and alternative configuration methods.

#### `config.server_timing`

When `true`, adds the [ServerTiming middleware](#actiondispatch-servertiming)
to the middleware stack

#### `config.session_options`

Additional options passed to `config.session_store`. You should use
`config.session_store` to set this instead of modifying it yourself.

```ruby
config.session_store :cookie_store, key: "_your_app_session"
config.session_options # => {key: "_your_app_session"}
```

#### `config.session_store`

Specifies what class to use to store the session. Possible values are `:cache_store`, `:cookie_store`, `:mem_cache_store`, a custom store, or `:disabled`. `:disabled` tells Rails not to deal with sessions.

This setting is configured via a regular method call, rather than a setter. This allows additional options to be passed:

```ruby
config.session_store :cookie_store, key: "_your_app_session"
```

If a custom store is specified as a symbol, it will be resolved to the `ActionDispatch::Session` namespace:

```ruby
# use ActionDispatch::Session::MyCustomStore as the session store
config.session_store :my_custom_store
```

The default store is a cookie store with the application name as the session key.

#### `config.ssl_options`

Configuration options for the [`ActionDispatch::SSL`](https://api.rubyonrails.org/classes/ActionDispatch/SSL.html) middleware.

The default value depends on the `config.load_defaults` target version:

| Starting with version | The default value is |
| --------------------- | -------------------- |
| (original)            | `{}`                 |
| 5.0                   | `{ hsts: { subdomains: true } }` |

#### `config.time_zone`

Sets the default time zone for the application and enables time zone awareness for Active Record.

#### `config.x`

Used to easily add nested custom configuration to the application config object

  ```ruby
  config.x.payment_processing.schedule = :daily
  Rails.configuration.x.payment_processing.schedule # => :daily
  ```

See [Custom Configuration](#custom-configuration)

### Configuring Assets

#### `config.assets.css_compressor`

Defines the CSS compressor to use. It is set by default by `sass-rails`. The unique alternative value at the moment is `:yui`, which uses the `yui-compressor` gem.

#### `config.assets.js_compressor`

Defines the JavaScript compressor to use. Possible values are `:terser`, `:closure`, `:uglifier`, and `:yui`, which require the use of the `terser`, `closure-compiler`, `uglifier`, or `yui-compressor` gems respectively.

#### `config.assets.gzip`

A flag that enables the creation of gzipped version of compiled assets, along with non-gzipped assets. Set to `true` by default.

#### `config.assets.paths`

Contains the paths which are used to look for assets. Appending paths to this configuration option will cause those paths to be used in the search for assets.

#### `config.assets.precompile`

Allows you to specify additional assets (other than `application.css` and `application.js`) which are to be precompiled when `rake assets:precompile` is run.

#### `config.assets.unknown_asset_fallback`

Allows you to modify the behavior of the asset pipeline when an asset is not in the pipeline, if you use sprockets-rails 3.2.0 or newer.

The default value depends on the `config.load_defaults` target version:

| Starting with version | The default value is |
| --------------------- | -------------------- |
| (original)            | `true`               |
| 5.1                   | `false`              |

#### `config.assets.prefix`

Defines the prefix where assets are served from. Defaults to `/assets`.

#### `config.assets.manifest`

Defines the full path to be used for the asset precompiler's manifest file. Defaults to a file named `manifest-<random>.json` in the `config.assets.prefix` directory within the public folder.

#### `config.assets.digest`

Enables the use of SHA256 fingerprints in asset names. Set to `true` by default.

#### `config.assets.debug`

Disables the concatenation and compression of assets. Set to `true` by default in `development.rb`.

#### `config.assets.version`

Is an option string that is used in SHA256 hash generation. This can be changed to force all files to be recompiled.

#### `config.assets.compile`

Is a boolean that can be used to turn on live Sprockets compilation in production.

#### `config.assets.logger`

Accepts a logger conforming to the interface of Log4r or the default Ruby `Logger` class. Defaults to the same configured at `config.logger`. Setting `config.assets.logger` to `false` will turn off served assets logging.

#### `config.assets.quiet`

Disables logging of assets requests. Set to `true` by default in `development.rb`.

### Configuring Generators

Rails allows you to alter what generators are used with the `config.generators` method. This method takes a block:

```ruby
config.generators do |g|
  g.orm :active_record
  g.test_framework :test_unit
end
```

The full set of methods that can be used in this block are as follows:

* `force_plural` allows pluralized model names. Defaults to `false`.
* `helper` defines whether or not to generate helpers. Defaults to `true`.
* `integration_tool` defines which integration tool to use to generate integration tests. Defaults to `:test_unit`.
* `system_tests` defines which integration tool to use to generate system tests. Defaults to `:test_unit`.
* `orm` defines which orm to use. Defaults to `false` and will use Active Record by default.
* `resource_controller` defines which generator to use for generating a controller when using `bin/rails generate resource`. Defaults to `:controller`.
* `resource_route` defines whether a resource route definition should be generated
  or not. Defaults to `true`.
* `scaffold_controller` different from `resource_controller`, defines which generator to use for generating a _scaffolded_ controller when using `bin/rails generate scaffold`. Defaults to `:scaffold_controller`.
* `test_framework` defines which test framework to use. Defaults to `false` and will use minitest by default.
* `template_engine` defines which template engine to use, such as ERB or Haml. Defaults to `:erb`.

### Configuring Middleware

Every Rails application comes with a standard set of middleware which it uses in this order in the development environment:

#### `ActionDispatch::HostAuthorization`

Prevents against DNS rebinding and other `Host` header attacks.
It is included in the development environment by default with the following configuration:

```ruby
Rails.application.config.hosts = [
  IPAddr.new("0.0.0.0/0"),        # All IPv4 addresses.
  IPAddr.new("::/0"),             # All IPv6 addresses.
  "localhost",                    # The localhost reserved domain.
  ENV["RAILS_DEVELOPMENT_HOSTS"]  # Additional comma-separated hosts for development.
]
```

In other environments `Rails.application.config.hosts` is empty and no
`Host` header checks will be done. If you want to guard against header
attacks on production, you have to manually permit the allowed hosts
with:

```ruby
Rails.application.config.hosts << "product.com"
```

The host of a request is checked against the `hosts` entries with the case
operator (`#===`), which lets `hosts` support entries of type `Regexp`,
`Proc` and `IPAddr` to name a few. Here is an example with a regexp.

```ruby
# Allow requests from subdomains like `www.product.com` and
# `beta1.product.com`.
Rails.application.config.hosts << /.*\.product\.com/
```

The provided regexp will be wrapped with both anchors (`\A` and `\z`) so it
must match the entire hostname. `/product.com/`, for example, once anchored,
would fail to match `www.product.com`.

A special case is supported that allows you to permit all sub-domains:

```ruby
# Allow requests from subdomains like `www.product.com` and
# `beta1.product.com`.
Rails.application.config.hosts << ".product.com"
```

You can exclude certain requests from Host Authorization checks by setting
`config.host_authorization.exclude`:

```ruby
# Exclude requests for the /healthcheck/ path from host checking
Rails.application.config.host_authorization = {
  exclude: ->(request) { request.path =~ /healthcheck/ }
}
```

When a request comes to an unauthorized host, a default Rack application
will run and respond with `403 Forbidden`. This can be customized by setting
`config.host_authorization.response_app`. For example:

```ruby
Rails.application.config.host_authorization = {
  response_app: -> env do
    [400, { "Content-Type" => "text/plain" }, ["Bad Request"]]
  end
}
```

#### `ActionDispatch::ServerTiming`

Adds metrics to the `Server-Timing` header to be viewed in the dev tools of a
browser.

#### `ActionDispatch::SSL`

Forces every request to be served using HTTPS. Enabled if `config.force_ssl` is set to `true`. Options passed to this can be configured by setting `config.ssl_options`.

#### `ActionDispatch::Static`

Is used to serve static assets. Disabled if `config.public_file_server.enabled` is `false`. Set `config.public_file_server.index_name` if you need to serve a static directory index file that is not named `index`. For example, to serve `main.html` instead of `index.html` for directory requests, set `config.public_file_server.index_name` to `"main"`.

#### `ActionDispatch::Executor`

Allows thread safe code reloading. Disabled if `config.allow_concurrency` is `false`, which causes `Rack::Lock` to be loaded. `Rack::Lock` wraps the app in mutex so it can only be called by a single thread at a time.

#### `ActiveSupport::Cache::Strategy::LocalCache`

Serves as a basic memory backed cache. This cache is not thread safe and is intended only for serving as a temporary memory cache for a single thread.

#### `Rack::Runtime`

Sets an `X-Runtime` header, containing the time (in seconds) taken to execute the request.

#### `Rails::Rack::Logger`

Notifies the logs that the request has begun. After request is complete, flushes all the logs.

#### `ActionDispatch::ShowExceptions`

Rescues any exception returned by the application and renders nice exception pages if the request is local or if `config.consider_all_requests_local` is set to `true`. If `config.action_dispatch.show_exceptions` is set to `false`, exceptions will be raised regardless.

#### `ActionDispatch::RequestId`

Makes a unique X-Request-Id header available to the response and enables the `ActionDispatch::Request#uuid` method. Configurable with `config.action_dispatch.request_id_header`.

#### `ActionDispatch::RemoteIp`

Checks for IP spoofing attacks and gets valid `client_ip` from request headers. Configurable with the `config.action_dispatch.ip_spoofing_check`, and `config.action_dispatch.trusted_proxies` options.

#### `Rack::Sendfile`

Intercepts responses whose body is being served from a file and replaces it with a server specific X-Sendfile header. Configurable with `config.action_dispatch.x_sendfile_header`.

#### `ActionDispatch::Callbacks`

Runs the prepare callbacks before serving the request.

#### `ActionDispatch::Cookies`

Sets cookies for the request.

#### `ActionDispatch::Session::CookieStore`

Is responsible for storing the session in cookies. An alternate middleware can be used for this by changing [`config.session_store`](#config-session-store).

#### `ActionDispatch::Flash`

Sets up the `flash` keys. Only available if [`config.session_store`](#config-session-store) is set to a value.

#### `Rack::MethodOverride`

Allows the method to be overridden if `params[:_method]` is set. This is the middleware which supports the PATCH, PUT, and DELETE HTTP method types.

#### `Rack::Head`

Converts HEAD requests to GET requests and serves them as so.

#### Adding Custom Middleware

Besides these usual middleware, you can add your own by using the `config.middleware.use` method:

```ruby
config.middleware.use Magical::Unicorns
```

This will put the `Magical::Unicorns` middleware on the end of the stack. You can use `insert_before` if you wish to add a middleware before another.

```ruby
config.middleware.insert_before Rack::Head, Magical::Unicorns
```

Or you can insert a middleware to exact position by using indexes. For example, if you want to insert `Magical::Unicorns` middleware on top of the stack, you can do it, like so:

```ruby
config.middleware.insert_before 0, Magical::Unicorns
```

There's also `insert_after` which will insert a middleware after another:

```ruby
config.middleware.insert_after Rack::Head, Magical::Unicorns
```

Middlewares can also be completely swapped out and replaced with others:

```ruby
config.middleware.swap ActionController::Failsafe, Lifo::Failsafe
```

Middlewares can be moved from one place to another:

```ruby
config.middleware.move_before ActionDispatch::Flash, Magical::Unicorns
```

This will move the `Magical::Unicorns` middleware before
`ActionDispatch::Flash`. You can also move it after:

```ruby
config.middleware.move_after ActionDispatch::Flash, Magical::Unicorns
```

They can also be removed from the stack completely:

```ruby
config.middleware.delete Rack::MethodOverride
```

### Configuring i18n

All these configuration options are delegated to the `I18n` library.

#### `config.i18n.available_locales`

Defines the permitted available locales for the app. Defaults to all locale keys found in locale files, usually only `:en` on a new application.

#### `config.i18n.default_locale`

Sets the default locale of an application used for i18n. Defaults to `:en`.

#### `config.i18n.enforce_available_locales`

Ensures that all locales passed through i18n must be declared in the `available_locales` list, raising an `I18n::InvalidLocale` exception when setting an unavailable locale. Defaults to `true`. It is recommended not to disable this option unless strongly required, since this works as a security measure against setting any invalid locale from user input.

#### `config.i18n.load_path`

Sets the path Rails uses to look for locale files. Defaults to `config/locales/**/*.{yml,rb}`.

#### `config.i18n.raise_on_missing_translations`

Determines whether an error should be raised for missing translations
in controllers and views. This defaults to `false`.

#### `config.i18n.fallbacks`

Sets fallback behavior for missing translations. Here are 3 usage examples for this option:

  * You can set the option to `true` for using default locale as fallback, like so:

    ```ruby
    config.i18n.fallbacks = true
    ```

  * Or you can set an array of locales as fallback, like so:

    ```ruby
    config.i18n.fallbacks = [:tr, :en]
    ```

  * Or you can set different fallbacks for locales individually. For example, if you want to use `:tr` for `:az` and `:de`, `:en` for `:da` as fallbacks, you can do it, like so:

    ```ruby
    config.i18n.fallbacks = { az: :tr, da: [:de, :en] }
    #or
    config.i18n.fallbacks.map = { az: :tr, da: [:de, :en] }
    ```

### Configuring Active Model

#### `config.active_model.i18n_customize_full_message`

Controls whether the [`Error#full_message`][ActiveModel::Error#full_message] format can be overridden in an i18n locale file. Defaults to `false`.

When set to `true`, `full_message` will look for a format at the attribute and model level of the locale files. The default format is `"%{attribute} %{message}"`, where `attribute` is the name of the attribute, and `message` is the validation-specific message. The following example overrides the format for all `Person` attributes, as well as the format for a specific `Person` attribute (`age`).

```ruby
class Person
  include ActiveModel::Validations

  attr_accessor :name, :age

  validates :name, :age, presence: true
end
```

```yml
en:
  activemodel: # or activerecord:
    errors:
      models:
        person:
          # Override the format for all Person attributes:
          format: "Invalid %{attribute} (%{message})"
          attributes:
            age:
              # Override the format for the age attribute:
              format: "%{message}"
              blank: "Please fill in your %{attribute}"
```

```irb
irb> person = Person.new.tap(&:valid?)

irb> person.errors.full_messages
=> [
  "Invalid Name (can't be blank)",
  "Please fill in your Age"
]

irb> person.errors.messages
=> {
  :name => ["can't be blank"],
  :age  => ["Please fill in your Age"]
}
```

[ActiveModel::Error#full_message]: https://api.rubyonrails.org/classes/ActiveModel/Error.html#method-i-full_message

### Configuring Active Record

`config.active_record` includes a variety of configuration options:

#### `config.active_record.logger`

Accepts a logger conforming to the interface of Log4r or the default Ruby Logger class, which is then passed on to any new database connections made. You can retrieve this logger by calling `logger` on either an Active Record model class or an Active Record model instance. Set to `nil` to disable logging.

#### `config.active_record.primary_key_prefix_type`

Lets you adjust the naming for primary key columns. By default, Rails assumes that primary key columns are named `id` (and this configuration option doesn't need to be set). There are two other choices:

* `:table_name` would make the primary key for the Customer class `customerid`.
* `:table_name_with_underscore` would make the primary key for the Customer class `customer_id`.

#### `config.active_record.table_name_prefix`

Lets you set a global string to be prepended to table names. If you set this to `northwest_`, then the Customer class will look for `northwest_customers` as its table. The default is an empty string.

#### `config.active_record.table_name_suffix`

Lets you set a global string to be appended to table names. If you set this to `_northwest`, then the Customer class will look for `customers_northwest` as its table. The default is an empty string.

#### `config.active_record.schema_migrations_table_name`

Lets you set a string to be used as the name of the schema migrations table.

#### `config.active_record.internal_metadata_table_name`

Lets you set a string to be used as the name of the internal metadata table.

#### `config.active_record.protected_environments`

Lets you set an array of names of environments where destructive actions should be prohibited.

#### `config.active_record.pluralize_table_names`

Specifies whether Rails will look for singular or plural table names in the database. If set to `true` (the default), then the Customer class will use the `customers` table. If set to `false`, then the Customer class will use the `customer` table.

#### `config.active_record.default_timezone`

Determines whether to use `Time.local` (if set to `:local`) or `Time.utc` (if set to `:utc`) when pulling dates and times from the database. The default is `:utc`.

#### `config.active_record.schema_format`

Controls the format for dumping the database schema to a file. The options are `:ruby` (the default) for a database-independent version that depends on migrations, or `:sql` for a set of (potentially database-dependent) SQL statements.

#### `config.active_record.error_on_ignored_order`

Specifies if an error should be raised if the order of a query is ignored during a batch query. The options are `true` (raise error) or `false` (warn). Default is `false`.

#### `config.active_record.timestamped_migrations`

Controls whether migrations are numbered with serial integers or with timestamps. The default is `true`, to use timestamps, which are preferred if there are multiple developers working on the same application.

#### `config.active_record.migration_strategy`

Controls the strategy class used to perform schema statement methods in a migration. The default class
delegates to the connection adapter. Custom strategies should inherit from `ActiveRecord::Migration::ExecutionStrategy`,
or may inherit from `DefaultStrategy`, which will preserve the default behaviour for methods that aren't implemented:

```ruby
class CustomMigrationStrategy < ActiveRecord::Migration::DefaultStrategy
  def drop_table(*)
    raise "Dropping tables is not supported!"
  end
end

config.active_record.migration_strategy = CustomMigrationStrategy
```

#### `config.active_record.lock_optimistically`

Controls whether Active Record will use optimistic locking and is `true` by default.

#### `config.active_record.cache_timestamp_format`

Controls the format of the timestamp value in the cache key. Default is `:usec`.

#### `config.active_record.record_timestamps`

Is a boolean value which controls whether or not timestamping of `create` and `update` operations on a model occur. The default value is `true`.

#### `config.active_record.partial_inserts`

Is a boolean value and controls whether or not partial writes are used when creating new records (i.e. whether inserts only set attributes that are different from the default).

The default value depends on the `config.load_defaults` target version:

| Starting with version | The default value is |
| --------------------- | -------------------- |
| (original)            | `true`               |
| 7.0                   | `false`              |

#### `config.active_record.partial_updates`

Is a boolean value and controls whether or not partial writes are used when updating existing records (i.e. whether updates only set attributes that are dirty). Note that when using partial updates, you should also use optimistic locking `config.active_record.lock_optimistically` since concurrent updates may write attributes based on a possibly stale read state. The default value is `true`.

#### `config.active_record.maintain_test_schema`

Is a boolean value which controls whether Active Record should try to keep your test database schema up-to-date with `db/schema.rb` (or `db/structure.sql`) when you run your tests. The default is `true`.

#### `config.active_record.dump_schema_after_migration`

Is a flag which controls whether or not schema dump should happen
(`db/schema.rb` or `db/structure.sql`) when you run migrations. This is set to
`false` in `config/environments/production.rb` which is generated by Rails. The
default value is `true` if this configuration is not set.

#### `config.active_record.dump_schemas`

Controls which database schemas will be dumped when calling `db:schema:dump`.
The options are `:schema_search_path` (the default) which dumps any schemas listed in `schema_search_path`,
`:all` which always dumps all schemas regardless of the `schema_search_path`,
or a string of comma separated schemas.

#### `config.active_record.belongs_to_required_by_default`

Is a boolean value and controls whether a record fails validation if
`belongs_to` association is not present.

The default value depends on the `config.load_defaults` target version:

| Starting with version | The default value is |
| --------------------- | -------------------- |
| (original)            | `nil`                |
| 5.0                   | `true`               |

#### `config.active_record.belongs_to_required_validates_foreign_key`

Enable validating only parent-related columns for presence when the parent is mandatory.
The previous behavior was to validate the presence of the parent record, which performed an extra query
to get the parent every time the child record was updated, even when parent has not changed.

| Starting with version | The default value is |
| --------------------- | --\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x2D\x20\x7C\x0A\x7C\x20\x28\x6F\x72\x69\x67\x69\x6E\x61\x6C\x29\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x7C\x20\x60\x74\x72\x75\x65\x60\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x7C\x0A\x7C\x20\x37\x2E\x31\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x7C\x20\x60\x66\x61\x6C\x73\x65\x60\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x7C\x0A\x0A\x23\x23\x23\x23\x20\x60\x63\x6F\x6E\x66\x69\x67\x2E\x61\x63\x74\x69\x76\x65\x5F\x72\x65\x63\x6F\x72\x64\x2E\x61\x63\x74\x69\x6F\x6E\x5F\x6F\x6E\x5F\x73\x74\x72\x69\x63\x74\x5F\x6C\x6F\x61\x64\x69\x6E\x67\x5F\x76\x69\x6F\x6C\x61\x74\x69\x6F\x6E\x60\x0A\x0A\x45\x6E\x61\x62\x6C\x65\x73\x20\x72\x61\x69\x73\x69\x6E\x67\x20\x6F\x72\x20\x6C\x6F\x67\x67\x69\x6E\x67\x20\x61\x6E\x20\x65\x78\x63\x65\x70\x74\x69\x6F\x6E\x20\x69\x66\x20\x73\x74\x72\x69\x63\x74\x5F\x6C\x6F\x61\x64\x69\x6E\x67\x20\x69\x73\x20\x73\x65\x74\x20\x6F\x6E\x20\x61\x6E\x0A\x61\x73\x73\x6F\x63\x69\x61\x74\x69\x6F\x6E\x2E\x20\x54\x68\x65\x20\x64\x65\x66\x61\x75\x6C\x74\x20\x76\x61\x6C\x75\x65\x20\x69\x73\x20\x60\x3A\x72\x61\x69\x73\x65\x60\x20\x69\x6E\x20\x61\x6C\x6C\x20\x65\x6E\x76\x69\x72\x6F\x6E\x6D\x65\x6E\x74\x73\x2E\x20\x49\x74\x20\x63\x61\x6E\x20\x62\x65\x0A\x63\x68\x61\x6E\x67\x65\x64\x20\x74\x6F\x20\x60\x3A\x6C\x6F\x67\x60\x20\x74\x6F\x20\x73\x65\x6E\x64\x20\x76\x69\x6F\x6C\x61\x74\x69\x6F\x6E\x73\x20\x74\x6F\x20\x74\x68\x65\x20\x6C\x6F\x67\x67\x65\x72\x20\x69\x6E\x73\x74\x65\x61\x64\x20\x6F\x66\x20\x72\x61\x69\x73\x69\x6E\x67\x2E\x0A\x0A\x23\x23\x23\x23\x20\x60\x63\x6F\x6E\x66\x69\x67\x2E\x61\x63\x74\x69\x76\x65\x5F\x72\x65\x63\x6F\x72\x64\x2E\x73\x74\x72\x69\x63\x74\x5F\x6C\x6F\x61\x64\x69\x6E\x67\x5F\x62\x79\x5F\x64\x65\x66\x61\x75\x6C\x74\x60\x0A\x0A\x49\x73\x20\x61\x20\x62\x6F\x6F\x6C\x65\x61\x6E\x20\x76\x61\x6C\x75\x65\x20\x74\x68\x61\x74\x20\x65\x69\x74\x68\x65\x72\x20\x65\x6E\x61\x62\x6C\x65\x73\x20\x6F\x72\x20\x64\x69\x73\x61\x62\x6C\x65\x73\x20\x73\x74\x72\x69\x63\x74\x5F\x6C\x6F\x61\x64\x69\x6E\x67\x20\x6D\x6F\x64\x65\x20\x62\x79\x0A\x64\x65\x66\x61\x75\x6C\x74\x2E\x20\x44\x65\x66\x61\x75\x6C\x74\x73\x20\x74\x6F\x20\x60\x66\x61\x6C\x73\x65\x60\x2E\x0A\x0A\x23\x23\x23\x23\x20\x60\x63\x6F\x6E\x66\x69\x67\x2E\x61\x63\x74\x69\x76\x65\x5F\x72\x65\x63\x6F\x72\x64\x2E\x77\x61\x72\x6E\x5F\x6F\x6E\x5F\x72\x65\x63\x6F\x72\x64\x73\x5F\x66\x65\x74\x63\x68\x65\x64\x5F\x67\x72\x65\x61\x74\x65\x72\x5F\x74\x68\x61\x6E\x60\x0A\x0A\x41\x6C\x6C\x6F\x77\x73\x20\x73\x65\x74\x74\x69\x6E\x67\x20\x61\x20\x77\x61\x72\x6E\x69\x6E\x67\x20\x74\x68\x72\x65\x73\x68\x6F\x6C\x64\x20\x66\x6F\x72\x20\x71\x75\x65\x72\x79\x20\x72\x65\x73\x75\x6C\x74\x20\x73\x69\x7A\x65\x2E\x20\x49\x66\x20\x74\x68\x65\x20\x6E\x75\x6D\x62\x65\x72\x20\x6F\x66\x0A\x72\x65\x63\x6F\x72\x64\x73\x20\x72\x65\x74\x75\x72\x6E\x65\x64\x20\x62\x79\x20\x61\x20\x71\x75\x65\x72\x79\x20\x65\x78\x63\x65\x65\x64\x73\x20\x74\x68\x65\x20\x74\x68\x72\x65\x73\x68\x6F\x6C\x64\x2C\x20\x61\x20\x77\x61\x72\x6E\x69\x6E\x67\x20\x69\x73\x20\x6C\x6F\x67\x67\x65\x64\x2E\x20\x54\x68\x69\x73\x0A\x63\x61\x6E\x20\x62\x65\x20\x75\x73\x65\x64\x20\x74\x6F\x20\x69\x64\x65\x6E\x74\x69\x66\x79\x20\x71\x75\x65\x72\x69\x65\x73\x20\x77\x68\x69\x63\x68\x20\x6D\x69\x67\x68\x74\x20\x62\x65\x20\x63\x61\x75\x73\x69\x6E\x67\x20\x61\x20\x6D\x65\x6D\x6F\x72\x79\x20\x62\x6C\x6F\x61\x74\x2E\x0A\x0A\x23\x23\x23\x23\x20\x60\x63\x6F\x6E\x66\x69\x67\x2E\x61\x63\x74\x69\x76\x65\x5F\x72\x65\x63\x6F\x72\x64\x2E\x69\x6E\x64\x65\x78\x5F\x6E\x65\x73\x74\x65\x64\x5F\x61\x74\x74\x72\x69\x62\x75\x74\x65\x5F\x65\x72\x72\x6F\x72\x73\x60\x0A\x0A\x41\x6C\x6C\x6F\x77\x73\x20\x65\x72\x72\x6F\x72\x73\x20\x66\x6F\x72\x20\x6E\x65\x73\x74\x65\x64\x20\x60\x68\x61\x73\x5F\x6D\x61\x6E\x79\x60\x20\x72\x65\x6C\x61\x74\x69\x6F\x6E\x73\x68\x69\x70\x73\x20\x74\x6F\x20\x62\x65\x20\x64\x69\x73\x70\x6C\x61\x79\x65\x64\x20\x77\x69\x74\x68\x20\x61\x6E\x20\x69\x6E\x64\x65\x78\x0A\x61\x73\x20\x77\x65\x6C\x6C\x20\x61\x73\x20\x74\x68\x65\x20\x65\x72\x72\x6F\x72\x2E\x20\x44\x65\x66\x61\x75\x6C\x74\x73\x20\x74\x6F\x2 