# frozen_string_literal: true

# The MIT License (MIT)
#
# Copyright (c) 2014 Silvio Montanari
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This class based on https://github.com/smontanari/qunit-selenium, with a few tweaks to make it easier to read output.
class TestRun
  TestResult = Struct.new(:tests, :assertions, :duration, :raw_output)

  ID_TESTRESULT = "qunit-testresult"
  ID_TESTS = "qunit-tests"

  def initialize(driver)
    @qunit_testresult = driver[ID_TESTRESULT]
    @qunit_tests = driver[ID_TESTS]
  end

  def completed?
    @qunit_testresult.text =~ /Tests completed/
  end

  def result
    assertions = { total: total_assertions, passed: passed_assertions, failed: failed_assertions }
    tests = { total: total_tests, passed: pass_tests, failed: fail_tests }
    TestResult.new(tests, assertions, duration, raw_output)
  end

  private
    def raw_output
      @qunit_tests.text
    end

    def duration
      match = /Tests completed in (?<milliseconds>\d+) milliseconds/.match @qunit_testresult.text
      match[:milliseconds].to_i / 1000
    end

    %w(total passed failed).each do |result|
      define_method("#{result}_assertions".to_sym) do
        @qunit_testresult.find_elements(:class, result).first.text.to_i
      end
    end

    def total_tests
      @qunit_tests.find_elements(:css, "##{ID_TESTS} > *").count
    end

    %w(pass fail).each do |result|
      define_method("#{result}_tests".to_sym) do
        @qunit_tests.find_elements(:css, "##{ID_TESTS} > .#{result}").count
      end
    end
end
