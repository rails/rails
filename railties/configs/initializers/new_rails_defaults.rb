# These settins change the behavior of Rails 2 apps and will be defaults
# for Rails 3. You can remove this initializer when Rails 3 is released.

# Only save the attributes that have changed since the record was loaded.
ActiveRecord::Base.partial_updates = true

# Include ActiveRecord class name as root for JSON serialized output.
ActiveRecord::Base.include_root_in_json = true

# Use ISO 8601 format for JSON serialized times and dates
ActiveSupport.use_standard_json_time_format = true

# Don't escape HTML entities in JSON, leave that for the #json_escape helper
# if you're including raw json in an HTML page.
ActiveSupport.escape_html_entities_in_json = false