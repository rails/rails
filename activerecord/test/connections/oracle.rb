ENV['ARCONN'] = 'oracle'

# uses oracle_enhanced adapter in ENV['ORACLE_ENHANCED_PATH'] or from github.com/rsim/oracle-enhanced.git
require 'active_record/connection_adapters/oracle_enhanced_adapter'

# otherwise failed with silence_warnings method missing exception
require 'active_support/core_ext/kernel/reporting'
