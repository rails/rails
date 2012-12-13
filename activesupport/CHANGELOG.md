## Rails 3.2.10 (unreleased)

*   Remove surrogate unicode character encoding from ActiveSupport::JSON.encode
    The encoding scheme was broken for unicode characters outside the basic
    multilingual plane; since json is assumed to be UTF-8, and we already force the
    encoding to UTF-8 simply pass through the un-encoded characters.

    *Brett Carter*

*   Fix mocha v0.13.0 compatibility. *James Mead*

*   `#as_json` isolates options when encoding a hash. [Backport #8185]
    Fix #8182

    *Yves Senn*

*   Handle the possible Permission Denied errors atomic.rb might trigger due to
    its chown and chmod calls. [Backport #8027]

    *Daniele Sluijters*

## Rails 3.2.9 (Nov 12, 2012) ##

*   Add logger.push_tags and .pop_tags to complement logger.tagged:

        class Job
          def before
            Rails.logger.push_tags :jobs, self.class.name
          end

          def after
            Rails.logger.pop_tags 2
          end
        end

    *Jeremy Kemper*

*  Add %:z and %::z format string support to ActiveSupport::TimeWithZone#strftime. [fixes #6962] *kennyj*

## Rails 3.2.8 (Aug 9, 2012) ##

*   Fix ActiveSupport integration with Mocha > 0.12.1. *Mike Gunderloy*

*   Reverted the deprecation of ActiveSupport::JSON::Variable. *Rafael Mendonça França*

*   ERB::Util.html_escape now escapes single quotes. *Santiago Pastorino*

## Rails 3.2.7 (Jul 26, 2012) ##

*   Hash#fetch(fetch) is not the same as doing hash[key]

*   adds a missing require [fixes #6896]

*   make sure the inflection rules are loaded when cherry-picking active_support/core_ext/string/inflections.rb [fixes #6884]

*   Merge pull request #6857 from rsutphin/as_core_ext_time_missing_require

*   bump AS deprecation_horizon to 4.0

## Rails 3.2.6 (Jun 12, 2012) ##

*   No changes.

## Rails 3.2.5 (Jun 1, 2012) ##

*   ActiveSupport::JSON::Variable is deprecated. Define your own #as_json and #encode_json methods
    for custom JSON string literals. *Erich Menge*


## Rails 3.2.4 (May 31, 2012) ##

*   Added #beginning_of_hour and #end_of_hour to Time and DateTime core
    extensions. *Mark J. Titorenko*


## Rails 3.2.3 (March 30, 2012) ##

*   No changes.


## Rails 3.2.2 (March 1, 2012) ##

*   No changes.


## Rails 3.2.1 (January 26, 2012) ##

*   Documentation fixes and improvements.

*   Update time zone offset information. *Ravil Bayramgalin*

*   The deprecated `ActiveSupport::Base64.decode64` calls `::Base64.decode64`
    now. *Jonathan Viney*

*   Fixes uninitialized constant `ActiveSupport::TaggedLogging::ERROR`. *kennyj*


## Rails 3.2.0 (January 20, 2012) ##

*   ActiveSupport::Base64 is deprecated in favor of ::Base64. *Sergey Nartimov*

*   Module#synchronize is deprecated with no replacement.  Please use `monitor`
    from ruby's standard library.

*   (Date|DateTime|Time)#beginning_of_week accept an optional argument to
    be able to set the day at which weeks are assumed to start.

*   Deprecated ActiveSupport::MessageEncryptor#encrypt and decrypt. *José Valim*

*   ActiveSupport::Notifications.subscribed provides subscriptions to events while a block runs. *fxn*

*   Module#qualified_const_(defined?|get|set) are analogous to the corresponding methods
    in the standard API, but accept qualified constant names. *fxn*

*   Added inflection #deconstantize which complements #demodulize. This inflection
    removes the righmost segment in a qualified constant name. *fxn*

*   Added ActiveSupport:TaggedLogging that can wrap any standard Logger class to provide tagging capabilities *DHH*

        Logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
        Logger.tagged("BCX") { Logger.info "Stuff" }                            # Logs "[BCX] Stuff"
        Logger.tagged("BCX", "Jason") { Logger.info "Stuff" }                   # Logs "[BCX] [Jason] Stuff"
        Logger.tagged("BCX") { Logger.tagged("Jason") { Logger.info "Stuff" } } # Logs "[BCX] [Jason] Stuff"

*   Added safe_constantize that constantizes a string but returns nil instead of an exception if the constant (or part of it) does not exist *Ryan Oblak*

*   ActiveSupport::OrderedHash is now marked as extractable when using Array#extract_options! *Prem Sichanugrist*

*   Added Array#prepend as an alias for Array#unshift and Array#append as an alias for Array#<< *DHH*

*   The definition of blank string for Ruby 1.9 has been extended to Unicode whitespace.
    Also, in 1.8 the ideographic space U+3000 is considered to be whitespace. *Akira Matsuda, Damien Mathieu*

*   The inflector understands acronyms. *dlee*

*   Deprecated ActiveSupport::Memoizable in favor of Ruby memoization pattern *José Valim*

*   Added Time#all_day/week/quarter/year as a way of generating ranges (example: Event.where(created_at: Time.now.all_week)) *DHH*

*   Added instance_accessor: false as an option to Class#cattr_accessor and friends *DHH*

*   Removed ActiveSupport::SecureRandom in favor of SecureRandom from the standard library *Jon Leighton*

*   ActiveSupport::OrderedHash now has different behavior for #each and
    \#each_pair when given a block accepting its parameters with a splat. *Andrew Radev*

*   ActiveSupport::BufferedLogger#silence is deprecated.  If you want to squelch
    logs for a certain block, change the log level for that block.

*   ActiveSupport::BufferedLogger#open_log is deprecated.  This method should
    not have been public in the first place.

*   ActiveSupport::BufferedLogger's behavior of automatically creating the
    directory for your log file is deprecated.  Please make sure to create the
    directory for your log file before instantiating.

*   ActiveSupport::BufferedLogger#auto_flushing is deprecated.  Either set the
    sync level on the underlying file handle like this:

        f = File.open('foo.log', 'w')
        f.sync = true
        ActiveSupport::BufferedLogger.new f

    Or tune your filesystem.  The FS cache is now what controls flushing.

*   ActiveSupport::BufferedLogger#flush is deprecated.  Set sync on your
    filehandle, or tune your filesystem.

Please check [3-1-stable](https://github.com/rails/rails/blob/3-1-stable/activesupport/CHANGELOG.md) for previous changes.
