# Multi-db Configuration
#
# This file is used for configuration settings related to multiple databases.
#
# Enable Database Selector
#
# Inserts middleware to perform automatic connection switching.
# The `database_selector` hash is used to pass options to the DatabaseSelector
# middleware. The `delay` is used to determine how long to wait after a write
# to send a subsequent read to the primary.
#
# The `database_resolver` class is used by the middleware to determine which
# database is appropriate to use based on the time delay.
#
# The `database_resolver_context` class is used by the middleware to set
# timestamps for the last write to the primary. The resolver uses the context
# class timestamps to determine how long to wait before reading from the
# replica.
#
# By default Rails will store a last write timestamp in the session. The
# DatabaseSelector middleware is designed as such you can define your own
# strategy for connection switching and pass that into the middleware through
# these configuration options.
#
# Rails.application.configure do
#   config.active_record.database_selector = { delay: 2.seconds }
#   config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
#   config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
# end
#
# Enable Shard Selector
#
# Inserts middleware to perform automatic shard swapping. The `shard_selector` hash
# can be used to pass options to the `ShardSelector` middleware. The `lock` option is
# used to determine whether shard swapping should be prohibited for the request.
#
# The `shard_resolver` option is used by the middleware to determine which shard
# to switch to. The application must provide a mechanism for finding the shard name
# in a proc. See guides for an example.
#
# Rails.application.configure do
#   config.active_record.shard_selector = { lock: true }
#   config.active_record.shard_resolver = ->(request) { Tenant.find_by!(host: request.host).shard }
# end
