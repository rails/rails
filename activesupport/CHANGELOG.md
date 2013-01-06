## Rails 3.1.10 (Jan 8, 2012) ##

*   Hash.from_xml raises when it encounters type="symbol" or type="yaml".
    Use Hash.from_trusted_xml to parse this XML.

    CVE-2013-0156

    *Jeremy Kemper*

## Rails 3.1.9

## Rails 3.1.8 (Aug 9, 2012)

*   ERB::Util.html_escape now escapes single quotes. *Santiago Pastorino*

## Rails 3.1.7 (Jul 26, 2012)

*   No changes.

## Rails 3.1.6 (Jun 12, 2012)

*   No changes.

## Rails 3.1.5 (May 31, 2012) ##

*   call binmode on the tempfile for Ruby 1.8 compatibility

*   Stop SafeBuffer#clone_empty from issuing warnings

*   Use 1.9 native XML escaping to speed up html_escape and shush regexp warnings

## Rails 3.1.1 (October 7, 2011) ##

*   ruby193: String#prepend is also unsafe *Akira Matsuda*

*   Fix obviously breakage of Time.=== for Time subclasses *jeremyevans*

*   Added fix so that file store does not raise an exception when cache dir does
    not exist yet. This can happen if a delete_matched is called before anything
    is saved in the cache. *Philippe Huibonhoa*

*   Fixed performance issue where TimeZone lookups would require tzinfo each time *Tim Lucas*

*   ActiveSupport::OrderedHash is now marked as extractable when using Array#extract_options! *Prem Sichanugrist*

## Rails 3.1.0 (August 30, 2011) ##

*   ActiveSupport::Dependencies#load and ActiveSupport::Dependencies#require now
    return the value from `super` *Aaron Patterson*

*   Fixed ActiveSupport::Gzip to work properly in Ruby 1.8 *Guillermo Iguaran*

*   Kernel.require_library_or_gem was deprecated and will be removed in Rails 3.2.0 *Josh Kalderimis*

*   ActiveSupport::Duration#duplicable? was fixed for Ruby 1.8 *thedarkone*

*   ActiveSupport::BufferedLogger set log encoding to BINARY, but still use text
    mode to output portable newlines. *fxn*

*   ActiveSupport::Dependencies now raises NameError if it finds an existing constant in load_missing_constant. This better reflects the nature of the error which is usually caused by calling constantize on a nested constant. *Andrew White*

*   Deprecated ActiveSupport::SecureRandom in favour of SecureRandom from the standard library *Jon Leighton*

*   New reporting method Kernel#quietly. *fxn*

*   Add String#inquiry as a convenience method for turning a string into a StringInquirer object *DHH*

*   Add Object#in? to test if an object is included in another object *Prem Sichanugrist, Brian Morearty, John Reitano*

*   LocalCache strategy is now a real middleware class, not an anonymous class
    posing for pictures.

*   ActiveSupport::Dependencies::ClassCache class has been introduced for
    holding references to reloadable classes.

*   ActiveSupport::Dependencies::Reference has been refactored to take direct
    advantage of the new ClassCache.

*   Backports Range#cover? as an alias for Range#include? in Ruby 1.8 *Diego Carrion, fxn*

*   Added weeks_ago and prev_week to Date/DateTime/Time. *Rob Zolkos, fxn*

*   Added before_remove_const callback to ActiveSupport::Dependencies.remove_unloadable_constants! *Andrew White*

*   JSON decoding now uses the multi_json gem which also vendors a json engine called OkJson. The yaml backend has been removed in favor of OkJson as a default engine for 1.8.x, while the built in 1.9.x json implementation will be used by default. *Josh Kalderimis*

Please check [3-0-stable](https://github.com/rails/rails/blob/3-0-stable/activesupport/CHANGELOG) for previous changes.
