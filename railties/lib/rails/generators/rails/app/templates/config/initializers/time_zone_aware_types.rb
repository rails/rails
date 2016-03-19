# Be sure to restart your server when you modify this file.

# Store `Time` columns as time zone aware: if `config.time_zone` is set to a
# value other than `'UTC'`, `Time` columns will be treated as in that time zone.
# This is a new Rails 5.0 default, so it is introduced as a configuration option
# to ensure that apps made with earlier versions of Rails are not affected when
# upgrading.
Rails.application.config.active_record.time_zone_aware_types = [:datetime, :time]
