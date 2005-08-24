$:.unshift File.dirname(__FILE__) + "/../../lib"

require File.dirname(__FILE__) + "/../utils"
require 'test/unit'
require 'switchtower/scm/cvs'

class ScmCvsTest < Test::Unit::TestCase
  class CvsTest < SwitchTower::SCM::Cvs
    attr_accessor :story
    attr_reader   :last_path

    def cvs_log(path)
      @last_path = path
      story.shift
    end
  end

  class MockChannel
    attr_reader :sent_data

    def send_data(data)
      @sent_data ||= []
      @sent_data << data
    end

    def [](name)
      "value"
    end
  end

  class MockActor
    attr_reader :command
    attr_reader :channels
    attr_accessor :story

    def initialize(config)
      @config = config
    end

    def run(command)
      @command = command
      @channels ||= []
      @channels << MockChannel.new
      story.each { |stream, line| yield @channels.last, stream, line }
    end

    def release_path
      (@config[:now] || Time.now.utc).strftime("%Y%m%d%H%M%S")
    end

    def method_missing(sym, *args)
      @config.send(sym, *args)
    end
  end

  def setup
    @config = MockConfiguration.new
    @config[:repository] = ":ext:joetester@rubyforge.org:/hello/world"
    @config[:local] = "/hello/world"
    @config[:cvs] = "/path/to/cvs"
    @config[:password] = "chocolatebrownies"
    @config[:now] = Time.utc(2005,8,24,12,0,0)
    @scm = CvsTest.new(@config)
    @actor = MockActor.new(@config)
    @log_msg = <<MSG.strip
RCS file: /var/cvs/copland/copland/LICENSE,v
Working file: LICENSE
head: 1.1
branch:
locks: strict
access list:
keyword substitution: kv
total revisions: 1;     selected revisions: 1
description:
----------------------------
revision 1.1
date: 2004/08/29 04:23:36;  author: minam;  state: Exp;
New implementation.
=============================================================================

RCS file: /var/cvs/copland/copland/Rakefile,v
Working file: Rakefile
head: 1.7
branch:
locks: strict
access list:
keyword substitution: kv
total revisions: 7;     selected revisions: 1
description:
----------------------------
revision 1.7
date: 2004/09/15 16:35:01;  author: minam;  state: Exp;  lines: +2 -1
Rakefile now publishes package documentation from doc/packages instead of
doc/packrat. Updated "latest updates" in manual.
=============================================================================

RCS file: /var/cvs/copland/copland/TODO,v
Working file: TODO
head: 1.18
branch:
locks: strict
access list:
keyword substitution: kv
total revisions: 18;    selected revisions: 1
description:
----------------------------
revision 1.18
date: 2004/10/12 02:21:02;  author: minam;  state: Exp;  lines: +4 -1
Added RubyConf 2004 presentation.
=============================================================================

RCS file: /var/cvs/copland/copland/Attic/build-gemspec.rb,v
Working file: build-gemspec.rb
head: 1.5
branch:
locks: strict
access list:
keyword substitution: kv
total revisions: 5;     selected revisions: 1
description:
----------------------------
revision 1.5
date: 2004/08/29 04:10:17;  author: minam;  state: dead;  lines: +0 -0
Here we go -- point of no return. Deleting existing implementation to make
way for new implementation.
=============================================================================

RCS file: /var/cvs/copland/copland/copland.gemspec,v
Working file: copland.gemspec
head: 1.12
branch:
locks: strict
access list:
keyword substitution: kv
total revisions: 13;    selected revisions: 1
description:
----------------------------
revision 1.12
date: 2004/09/11 21:45:58;  author: minam;  state: Exp;  lines: +4 -4
Minor change in how version is communicated to gemspec.
=============================================================================
MSG
    @scm.story = [ @log_msg ]
  end

  def test_latest_revision
    @scm.story = [ @log_msg ]
    assert_equal "2004-10-12 02:21:02", @scm.latest_revision
    assert_equal "/hello/world", @scm.last_path
  end

  def test_checkout
    @actor.story = []
    assert_nothing_raised { @scm.checkout(@actor) }
    assert_nil @actor.channels.last.sent_data
    assert_match %r{/path/to/cvs}, @actor.command
  end

  def test_checkout_needs_ssh_password
    @actor.story = [[:out, "joetester@rubyforge.org's password: "]]
    assert_nothing_raised { @scm.checkout(@actor) }
    assert_equal ["chocolatebrownies\n"], @actor.channels.last.sent_data
  end
end
