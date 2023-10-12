# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 7.1 framework defaults upgrade.
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `7.1`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

###
# No longer add autoloaded paths into `$LOAD_PATH`. This means that you won't be able
# to manually require files that are managed by the autoloader, which you shouldn't do anyway.
#
# This will reduce the size of the load path, making `require` faster if you don't use bootsnap, or reduce the size
# of the bootsnap cache if you use it.
#++
# Rails.application.config.add_autoload_paths_to_load_path = false

###
# Remove the default X-Download-Options headers since it is used only by Internet Explorer.
# If you need to support Internet Explorer, add back `"X-Download-Options" => "noopen"`.
#++
# Rails.application.config.action_dispatch.default_headers = {
#   "X-Frame-Options" => "SAMEORIGIN",
#   "X-XSS-Protection" => "0",
#   "X-Content-Type-Options" => "nosniff",
#   "X-Permitted-Cross-Domain-Policies" => "none",
#   "Referrer-Policy" => "strict-origin-when-cross-origin"
# }

###
# Do not treat an `ActionController::Parameters` instance
# as equal to an equivalent `Hash` by default.
#++
# Rails.application.config.action_controller.allow_deprecated_parameters_hash_equality = false

###
# Active Record Encryption now uses SHA-256 as its hash digest algorithm.
# 
# There are 3 scenarios to consider.
#
# 1. If you have data encrypted with previous Rails versions, and you have
# +config.active_support.key_generator_hash_digest_class+ configured as SHA1 (the default
# before Rails 7.0), you need to configure SHA-1 for Active Record Encryption too:
#++
# Rails.application.config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA1
#
# 2. If you have +config.active_support.key_generator_hash_digest_class+ configured as SHA256 (the new default
# in 7.0), then you need to configure SHA-256 for Active Record Encryption:
#++
# Rails.application.config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256
#
# 3. If you don't currently have data encrypted with Active Record encryption, you can disable this setting to
# configure the default behavior starting 7.1+:
#++
# Rails.application.config.active_record.encryption.support_sha1_for_non_deterministic_encryption = false

###
# No longer run after_commit callbacks on the first of multiple Active Record
# instances to save changes to the same database row within a transaction.
# Instead, run these callbacks on the instance most likely to have internal
# state which matches what was committed to the database, typically the last
# instance to save.
#++
# Rails.application.config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction = false

###
# Configures SQLite with a strict strings mode, which disables double-quoted string literals.
#
# SQLite has some quirks around double-quoted string literals.
# It first tries to consider double-quoted strings as identifier names, but if they don't exist
# it then considers them as string literals. Because of this, typos can silently go unnoticed.
# For example, it is possible to create an index for a non existing column.
# See https://www.sqlite.org/quirks.html#double_quoted_string_literals_are_accepted for more details.
#++
# Rails.application.config.active_record.sqlite3_adapter_strict_strings_by_default = true

###
# Disable deprecated singular associations names.
#++
# Rails.application.config.active_record.allow_deprecated_singular_associations_name = false

###
# Enable the Active Job `BigDecimal` argument serializer, which guarantees
# roundtripping. Without this serializer, some queue adapters may serialize
# `BigDecimal` arguments as simple (non-roundtrippable) strings.
#
# When deploying an application with multiple replicas, old (pre-Rails 7.1)
# replicas will not be able to deserialize `BigDecimal` arguments from this
# serializer. Therefore, this setting should only be enabled after all replicas
# have been successfully upgraded to Rails 7.1.
#++
# Rails.application.config.active_job.use_big_decimal_serializer = true

###
# Specify if an `ArgumentError` should be raised if `Rails.cache` `fetch` or
# `write` are given an invalid `expires_at` or `expires_in` time.
# Options are `true`, and `false`. If `false`, the exception will be reported
# as `handled` and logged instead.
#++
# Rails.application.config.active_support.raise_on_invalid_cache_expiration_time = true

###
# Specify whether Query Logs will format tags using the SQLCommenter format
# (https://open-telemetry.github.io/opentelemetry-sqlcommenter/), or using the legacy format.
# Options are `:legacy` and `:sqlcommenter`.
#++
# Rails.application.config.active_record.query_log_tags_format = :sqlcommenter

###
# Specify the default serializer used by `MessageEncryptor` and `MessageVerifier`
# instances.
#
# The legacy default is `:marshal`, which is a potential vector for
# deserialization attacks in cases where a message signing secret has been
# leaked.
#
# In Rails 7.1, the new default is `:json_allow_marshal` which serializes and
# deserializes with `ActiveSupport::JSON`, but can fall back to deserializing
# with `Marshal` so that legacy messages can still be read.
#
# In Rails 7.2, the default will become `:json` which serializes and
# deserializes with `ActiveSupport::JSON` only.
#
# Alternatively, you can choose `:message_pack` or `:message_pack_allow_marshal`,
# which serialize with `ActiveSupport::MessagePack`. `ActiveSupport::MessagePack`
# can roundtrip some Ruby types that are not supported by JSON, and may provide
# improved performance, but it requires the `msgpack` gem.
#
# For more information, see
# https://guides.rubyonrails.org/v7.1/configuring.html#config-active-support-message-serializer
#
# If you are performing a rolling deploy of a Rails 7.1 upgrade, wherein servers
# that have not yet been upgraded must be able to read messages from upgraded
# servers, first deploy without changing the serializer, then set the serializer
# in a subsequent deploy.
#++
# Rails.application.config.active_support.message_serializer = :json_allow_marshal

###
# Enable a performance optimization that serializes message data and metadata
# together. This changes the message format, so messages serialized this way
# cannot be read by older versions of Rails. However, messages that use the old
# format can still be read, regardless of whether this optimization is enabled.
#
# To perform a rolling deploy of a Rails 7.1 upgrade, wherein servers that have
# not yet been upgraded must be able to read messages from upgraded servers,
# leave this optimization off on the first deploy, then enable it on a
# subsequent deploy.
#++
# Rails.application.config.active_support.use_message_serializer_for_metadata = true

###
# Set the maximum size for Rails log files.
#
# `config.load_defaults 7.1` does not set this value for environments other than
# development and test.
#++
# if Rails.env.local?
#   Rails.application.config.log_file_size = 100 * 1024 * 1024
# end

###
# Enable raising on assignment to attr_readonly attributes. The previous
# behavior would allow assignment but silently not persist changes to the
# database.
#++
# Rails.application.config.active_record.raise_on_assign_to_attr_readonly = true

###
# Enable validating only parent-related columns for presence when the parent is mandatory.
# The previous behavior was to validate the presence of the parent record, which performed an extra query
# to get the parent every time the child record was updated, even when parent has not changed.
#++
# Rails.application.config.active_record.belongs_to_required_validates_foreign_key = false

###
# Enable precompilation of `config.filter_parameters`. Precompilation can
# improve filtering performance, depending on the quantity and types of filters.
#++
# Rails.application.config.precompile_filter_parameters = true

###
# Enable before_committed! callbacks on all enrolled records in a transaction.
# The previous behavior was to only run the callbacks on the first copy of a record
# if there were multiple copies of the same record enrolled in the transaction.
#++
# Rails.application.config.active_record.before_committed_on_all_records = true

###
# Disable automatic column serialization into YAML.
# To keep the historic behavior, you can set it to `YAML`, however it is
# recommended to explicitly define the serialization method for each column
# rather than to rely on a global default.
#++
# Rails.application.config.active_record.default_column_serializer = nil

###
# Enable a performance optimization that serializes Active Record models
# in a faster and more compact way.
#
# To perform a rolling deploy of a Rails 7.1 upgrade, wherein servers that have
# not yet been upgraded must be able to read caches from upgraded servers,
# leave this optimization off on the first deploy, then enable it on a
# subsequent deploy.
#++
# Rails.application.config.active_record.marshalling_format_version = 7.1

###
# Run `after_commit` and `after_*_commit` callbacks in the order they are defined in a model.
# This matches the behaviour of all other callbacks.
# In previous versions of Rails, they ran in the inverse order.
#++
# Rails.application.config.active_record.run_after_transaction_callbacks_in_order_defined = true

###
# Whether a `transaction` block is committed or rolled back when exited via `return`, `break` or `throw`.
#++
# Rails.application.config.active_record.commit_transaction_on_non_local_return = true

###
# Controls when to generate a value for <tt>has_secure_token</tt> declarations.
#++
# Rails.application.config.active_record.generate_secure_token_on = :initialize

###
# ** Please read carefully, this must be configured in config/application.rb **
#
# Change the format of the cache entry.
#
# Changing this default means that all new cache entries added to the cache
# will have a different format that is not supported by Rails 7.0
# applications.
#
# Only change this value after your application is fully deployed to Rails 7.1
# and you have no plans to rollback.
# When you're ready to change format, add this to `config/application.rb` (NOT
# this file):
#   config.active_support.cache_format_version = 7.1


###
# Configure Action View to use HTML5 standards-compliant sanitizers when they are supported on your
# platform.
#
# `Rails::HTML::Sanitizer.best_supported_vendor` will cause Action View to use HTML5-compliant
# sanitizers if they are supported, else fall back to HTML4 sanitizers.
#
# In previous versions of Rails, Action View always used `Rails::HTML4::Sanitizer` as its vendor.
#++
# Rails.application.config.action_view.sanitizer_vendor = Rails::HTML::Sanitizer.best_supported_vendor


###
# Configure Action Text to use an HTML5 standards-compliant sanitizer when it is supported on your
# platform.
#
# `Rails::HTML::Sanitizer.best_supported_vendor` will cause Action Text to use HTML5-compliant
# sanitizers if they are supported, else fall back to HTML4 sanitizers.
#
# In previous versions of Rails, Action Text always used `Rails::HTML4::Sanitizer` as its vendor.
#++
# Rails.application.config.action_text.sanitizer_vendor = Rails::HTML::Sanitizer.best_supported_vendor


###
# Configure the log level used by the DebugExceptions middleware when logging
# uncaught exceptions during requests.
#++
# Rails.application.config.action_dispatch.debug_exception_log_level = :error


###
# Configure the test helpers in Action View, Action Dispatch, and rails-dom-testing to use HTML5
# parsers.
#
# Nokogiri::HTML5 isn't supported on JRuby, so JRuby applications must set this to :html4.
#
# In previous versions of Rails, these test helpers always used an HTML4 parser.
#++
# Rails.application.config.dom_testing_default_html_version = :html5
