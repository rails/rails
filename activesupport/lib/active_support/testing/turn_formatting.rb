# Turn gives you prettier formatting for MiniTest and inline failure reporting.
# It also allows us to report test cases in natural language rather than with underscores. Example:
#
# CommentsControllerTest:
#      PASS the truth (0.03s) 
# 
# APITest
#      test_api_without_subdomain                                            PASS
#      test_create_milestone_using_typed_xml                                 FAIL
#  	/test/integration/api_test.rb:50:in `test_create_milestone_using_typed_xml'
#  	<2006-05-01> expected but was
#  	<Mon May 01 07:00:00 UTC 2006>.
#      test_create_milestone_using_untyped_xml                               FAIL
#  	/test/integration/api_test.rb:38:in `test_create_milestone_using_untyped_xml'
#  	<2006-05-01> expected but was
#  	<Mon May 01 07:00:00 UTC 2006>.

#
# vs:
#
# .FF

if defined?(MiniTest)
  begin
    silence_warnings { require 'turn' }
  
    if MiniTest::Unit.respond_to?(:use_natural_language_case_names=)
      MiniTest::Unit.use_natural_language_case_names = true 
    end
  rescue LoadError
    # If there's no turn, that's fine, it's just formatting
  end
end