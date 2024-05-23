# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 7.2 framework defaults upgrade.
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `7.2`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

###
# Controls whether Active Job's `#perform_later` and similar methods automatically defer
# the job queuing to after the current Active Record transaction is committed.
#
# Example:
#   Topic.transaction do
#     topic = Topic.create(...)
#     NewTopicNotificationJob.perform_later(topic)
#   end
#
# In this example, if the configuration is set to `:never`, the job will
# be enqueued immediately, even though the `Topic` hasn't been committed yet.
# Because of this, if the job is picked up almost immediately, or if the
# transaction doesn't succeed for some reason, the job will fail to find this
# topic in the database.
#
# If `enqueue_after_transaction_commit` is set to `:default`, the queue adapter
# will define the behaviour.
#
# Note: Active Job backends can disable this feature. This is generally done by
# backends that use the same database as Active Record as a queue, hence they
# don't need this feature.
#++
# Rails.application.config.active_job.enqueue_after_transaction_commit = :default

###
# Adds image/webp to the list of content types Active Storage considers as an image
# Prevents automatic conversion to a fallback PNG, and assumes clients support WebP, as they support gif, jpeg, and png.
# This is possible due to broad browser support for WebP, but older browsers and email clients may still not support
# WebP. Requires imagemagick/libvips built with WebP support.
#++
# Rails.application.config.active_storage.web_image_content_types = %w[image/png image/jpeg image/gif image/webp]

###
# Enable validation of migration timestamps. When set, an ActiveRecord::InvalidMigrationTimestampError
# will be raised if the timestamp prefix for a migration is more than a day ahead of the timestamp
# associated with the current time. This is done to prevent forward-dating of migration files, which can
# impact migration generation and other migration commands.
#
# Applications with existing timestamped migrations that do not adhere to the
# expected format can disable validation by setting this config to `false`.
#++
# Rails.application.config.active_record.validate_migration_timestamps = true

###
# Controls whether the PostgresqlAdapter should decode dates automatically with manual queries.
#
# Example:
#   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.select_value("select '2024-01-01'::date") #=> Date
#
# This query used to return a `String`.
#++
# Rails.application.config.active_record.postgresql_adapter_decode_dates = true

###
# Enables YJIT as of Ruby 3.3, to bring sizeable performance improvements. If you are
# deploying to a memory constrained environment you may want to set this to `false`.
#++
# Rails.application.config.yjit = true
