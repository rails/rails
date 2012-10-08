Contributing to Ruby on Rails
=============================

This guide covers ways in which _you_ can become a part of the ongoing development of Ruby on Rails. After reading it, you should be familiar with:

* Using GitHub to report issues
* Cloning master and running the test suite
* Helping to resolve existing issues
* Contributing to the Ruby on Rails documentation
* Contributing to the Ruby on Rails code

Ruby on Rails is not "someone else's framework." Over the years, hundreds of people have contributed to Ruby on Rails ranging from a single character to massive architectural changes or significant documentation -- all with the goal of making Ruby on Rails better for everyone. Even if you don't feel up to writing code or documentation yet, there are a variety of other ways that you can contribute, from reporting issues to testing patches.

--------------------------------------------------------------------------------

Reporting an Issue
------------------

Ruby on Rails uses [GitHub Issue Tracking](https://github.com/rails/rails/issues) to track issues (primarily bugs and contributions of new code). If you've found a bug in Ruby on Rails, this is the place to start. You'll need to create a (free) GitHub account in order to submit an issue, to comment on them or to create pull requests.

NOTE: Bugs in the most recent released version of Ruby on Rails are likely to get the most attention. Also, the Rails core team is always interested in feedback from those who can take the time to test _edge Rails_ (the code for the version of Rails that is currently under development). Later in this guide you'll find out how to get edge Rails for testing.

### Creating a Bug Report

If you've found a problem in Ruby on Rails which is not a security risk, do a search in GitHub under [Issues](https://github.com/rails/rails/issues in case it was already reported. If you find no issue addressing it you can [add a new one](https://github.com/rails/rails/issues/new). (See the next section for reporting security issues).

At the minimum, your issue report needs a title and descriptive text. But that's only a minimum. You should include as much relevant information as possible. You need at least to post the code sample that has the issue. Even better is to include a unit test that shows how the expected behavior is not occurring. Your goal should be to make it easy for yourself -- and others -- to replicate the bug and figure out a fix.

Then, don't get your hopes up! Unless you have a "Code Red, Mission Critical, the World is Coming to an End" kind of bug, you're creating this issue report in the hope that others with the same problem will be able to collaborate with you on solving it. Do not expect that the issue report will automatically see any activity or that others will jump to fix it. Creating an issue like this is mostly to help yourself start on the path of fixing the problem and for others to confirm it with an "I'm having this problem too" comment.

### Special Treatment for Security Issues

WARNING: Please do not report security vulnerabilities with public GitHub issue reports. The [Rails security policy page](http://rubyonrails.org/security) details the procedure to follow for security issues.

### What about Feature Requests?

Please don't put "feature request" items into GitHub Issues. If there's a new feature that you want to see added to Ruby on Rails, you'll need to write the code yourself - or convince someone else to partner with you to write the code. Later in this guide you'll find detailed instructions for proposing a patch to Ruby on Rails. If you enter a wishlist item in GitHub Issues with no code, you can expect it to be marked "invalid" as soon as it's reviewed.

If you'd like feedback on an idea for a feature before doing the work for make a patch, please send an email to the [rails-core mailing list](https://groups.google.com/forum/?fromgroups#!forum/rubyonrails-core). You might get no response, which means that everyone is indifferent. You might find someone who's also interested in building that feature. You might get a "This won't be accepted." But it's the proper place to discuss new ideas. GitHub Issues are not a particularly good venue for the sometimes long and involved discussions new features require.

Setting Up a Development Environment
------------------------------------

To move on from submitting bugs to helping resolve existing issues or contributing your own code to Ruby on Rails, you _must_ be able to run its test suite. In this section of the guide you'll learn how to set up the tests on your own computer.

### The Easy Way

The easiest and recommended way to get a development environment ready to hack is to use the [Rails development box](https://github.com/rails/rails-dev-box).

### The Hard Way

In case you can't use the Rails development box, see section above, check [this other guide](development_dependencies_install.html).

Testing Active Record
---------------------

This is how you run the Active Record test suite only for SQLite3:

```bash
$ cd activerecord
$ bundle exec rake test_sqlite3
```

You can now run the tests as you did for `sqlite3`. The tasks are respectively

```bash
test_mysql
test_mysql2
test_postgresql
```

Finally,

```bash
$ bundle exec rake test
```

will now run the four of them in turn.

You can also run any single test separately:

```bash
$ ARCONN=sqlite3 ruby -Itest test/cases/associations/has_many_associations_test.rb
```

You can invoke `test_jdbcmysql`, `test_jdbcsqlite3` or `test_jdbcpostgresql` also. See the file `activerecord/RUNNING_UNIT_TESTS` for information on running more targeted database tests, or the file `ci/travis.rb` for the test suite run by the continuous integration server.

### Warnings

The test suite runs with warnings enabled. Ideally, Ruby on Rails should issue no warnings, but there may be a few, as well as some from third-party libraries. Please ignore (or fix!) them, if any, and submit patches that do not issue new warnings.

As of this writing (December, 2010) they are specially noisy with Ruby 1.9. If you are sure about what you are doing and would like to have a more clear output, there's a way to override the flag:

```bash
$ RUBYOPT=-W0 bundle exec rake test
```

### Older Versions of Ruby on Rails

If you want to add a fix to older versions of Ruby on Rails, you'll need to set up and switch to your own local tracking branch. Here is an example to switch to the 3-0-stable branch:

```bash
$ git branch --track 3-0-stable origin/3-0-stable
$ git checkout 3-0-stable
```

TIP: You may want to [put your Git branch name in your shell prompt](http://qugstart.com/blog/git-and-svn/add-colored-git-branch-name-to-your-shell-prompt/) to make it easier to remember which version of the code you're working with.

Helping to Resolve Existing Issues
----------------------------------

As a next step beyond reporting issues, you can help the core team resolve existing issues. If you check the [Everyone's Issues](https://github.com/rails/rails/issues) list in GitHub Issues, you'll find lots of issues already requiring attention. What can you do for these? Quite a bit, actually:

### Verifying Bug Reports

For starters, it helps just to verify bug reports. Can you reproduce the reported issue on your own computer? If so, you can add a comment to the issue saying that you're seeing the same thing.

If something is very vague, can you help squash it down into something specific? Maybe you can provide additional information to help reproduce a bug, or help by eliminating needless steps that aren't required to demonstrate the problem.

If you find a bug report without a test, it's very useful to contribute a failing test. This is also a great way to get started exploring the source code: looking at the existing test files will teach you how to write more tests. New tests are best contributed in the form of a patch, as explained later on in the "Contributing to the Rails Code" section.

Anything you can do to make bug reports more succinct or easier to reproduce is a help to folks trying to write code to fix those bugs - whether you end up writing the code yourself or not.

### Testing Patches

You can also help out by examining pull requests that have been submitted to Ruby on Rails via GitHub. To apply someone's changes you need first to create a dedicated branch:

```bash
$ git checkout -b testing_branch
```

Then you can use their remote branch to update your codebase. For example, let's say the GitHub user JohnSmith has forked and pushed to a topic branch "orange" located at https://github.com/JohnSmith/rails.

```bash
$ git remote add JohnSmith git://github.com/JohnSmith/rails.git
$ git pull JohnSmith orange
```

After applying their branch, test it out! Here are some things to think about:

* Does the change actually work?
* Are you happy with the tests? Can you follow what they're testing? Are there any tests missing?
* Does it have the proper documentation coverage? Should documentation elsewhere be updated?
* Do you like the implementation? Can you think of a nicer or faster way to implement a part of their change?

Once you're happy that the pull request contains a good change, comment on the GitHub issue indicating your approval. Your comment should indicate that you like the change and what you like about it. Something like:

<blockquote>
I like the way you've restructured that code in generate_finder_sql -- much nicer. The tests look good too.
</blockquote>

If your comment simply says "+1", then odds are that other reviewers aren't going to take it too seriously. Show that you took the time to review the pull request.

Contributing to the Rails Documentation
---------------------------------------

Ruby on Rails has two main sets of documentation: the guides help you in learning about Ruby on Rails, and the API is a reference.

You can help improve the Rails guides by making them more coherent, consistent or readable, adding missing information, correcting factual errors, fixing typos, or bringing it up to date with the latest edge Rails. To get involved in the translation of Rails guides, please see [Translating Rails Guides](https://wiki.github.com/lifo/docrails/translating-rails-guides).

If you're confident about your changes, you can push them directly yourself via [docrails](https://github.com/lifo/docrails). Docrails is a branch with an **open commit policy** and public write access. Commits to docrails are still reviewed, but this happens after they are pushed. Docrails is merged with master regularly, so you are effectively editing the Ruby on Rails documentation.

If you are unsure of the documentation changes, you can create an issue in the [Rails](https://github.com/rails/rails/issues) issues tracker on GitHub.

When working with documentation, please take into account the [API Documentation Guidelines](api_documentation_guidelines.html) and the [Ruby on Rails Guides Guidelines](ruby_on_rails_guides_guidelines.html).

NOTE: As explained earlier, ordinary code patches should have proper documentation coverage. Docrails is only used for isolated documentation improvements.

NOTE: To help our CI servers you can add [ci skip] to your documentation commit message to skip build on that commit. Please remember to use it for commits containing only documentation changes.

WARNING: Docrails has a very strict policy: no code can be touched whatsoever, no matter how trivial or small the change. Only RDoc and guides can be edited via docrails. Also, CHANGELOGs should never be edited in docrails.

Contributing to the Rails Code
------------------------------

### Clone the Rails Repository

The first thing you need to do to be able to contribute code is to clone the repository:

```bash
$ git clone git://github.com/rails/rails.git
```

and create a dedicated branch:

```bash
$ cd rails
$ git checkout -b my_new_branch
```

It doesn’t matter much what name you use, because this branch will only exist on your local computer and your personal repository on Github. It won't be part of the Rails Git repository.

### Write Your Code

Now get busy and add or edit code. You’re on your branch now, so you can write whatever you want (you can check to make sure you’re on the right branch with `git branch -a`). But if you’re planning to submit your change back for inclusion in Rails, keep a few things in mind:

* Get the code right.
* Use Rails idioms and helpers.
* Include tests that fail without your code, and pass with it.
* Update the (surrounding) documentation, examples elsewhere, and the guides: whatever is affected by your contribution.

TIP: Changes that are cosmetic in nature and do not add anything substantial to the stability, functionality, or testability of Rails will generally not be accepted.

### Follow the Coding Conventions

Rails follows a simple set of coding style conventions.

* Two spaces, no tabs (for indentation).
* No trailing whitespace. Blank lines should not have any spaces.
* Indent after private/protected.
* Prefer `&&`/`||` over `and`/`or`.
* Prefer class << self over self.method for class methods.
* Use `MyClass.my_method(my_arg)` not `my_method( my_arg )` or `my_method my_arg`.
* Use a = b and not a=b.
* Follow the conventions in the source you see used already.

The above are guidelines -- please use your best judgment in using them.

### Updating the CHANGELOG

The CHANGELOG is an important part of every release. It keeps the list of changes for every Rails version.

You should add an entry to the CHANGELOG of the framework that you modified if you're adding or removing a feature, commiting a bug fix or adding deprecation notices. Refactorings and documentation changes generally should not go to the CHANGELOG.

A CHANGELOG entry should summarize what was changed and should end with author's name. You can use multiple lines if you need more space and you can attach code examples indented with 4 spaces. If a change is related to a specific issue, you should attach issue's number. Here is an example CHANGELOG entry:

```
*   Summary of a change that briefly describes what was changed. You can use multiple
    lines and wrap them at around 80 characters. Code examples are ok, too, if needed:

        class Foo
          def bar
            puts 'baz'
          end
        end

    You can continue after the code example and you can attach issue number. GH#1234

    *Your Name*
```

Your name can be added directly after the last word if you don't provide any code examples or don't need multiple paragraphs. Otherwise, it's best to make as a new paragraph.

### Sanity Check

You should not be the only person who looks at the code before you submit it. You know at least one other Rails developer, right? Show them what you’re doing and ask for feedback. Doing this in private before you push a patch out publicly is the “smoke test” for a patch: if you can’t convince one other developer of the beauty of your code, you’re unlikely to convince the core team either.

You might want also to check out the [RailsBridge BugMash](http://wiki.railsbridge.org/projects/railsbridge/wiki/BugMash) as a way to get involved in a group effort to improve Rails. This can help you get started and help you check your code when you're writing your first patches.

### Commit Your Changes

When you're happy with the code on your computer, you need to commit the changes to Git:

```bash
$ git commit -a
```

At this point, your editor should be fired up and you can write a message for this commit. Well formatted and descriptive commit messages are extremely helpful for the others, especially when figuring out why given change was made, so please take the time to write it.

Good commit message should be formatted according to the following example:

```
Short summary (ideally 50 characters or less)

More detailed description, if necessary. It should be wrapped to 72
characters. Try to be as descriptive as you can, even if you think that
the commit content is obvious, it may not be obvious to others. You
should add such description also if it's already present in bug tracker,
it should not be necessary to visit a webpage to check the history.

Description can have multiple paragraphs and you can use code examples
inside, just indent it with 4 spaces:

    class PostsController
      def index
        respond_with Post.limit(10)
      end
    end

You can also add bullet points:

- you can use dashes or asterisks

- also, try to indent next line of a point for readability, if it's too
  long to fit in 72 characters
```

TIP. Please squash your commits into a single commit when appropriate. This simplifies future cherry picks, and also keeps the git log clean.

### Update Master

It’s pretty likely that other changes to master have happened while you were working. Go get them:

```bash
$ git checkout master
$ git pull --rebase
```

Now reapply your patch on top of the latest changes:

```bash
$ git checkout my_new_branch
$ git rebase master
```

No conflicts? Tests still pass? Change still seems reasonable to you? Then move on.

### Fork

Navigate to the Rails [GitHub repository](https://github.com/rails/rails) and press "Fork" in the upper right hand corner.

Add the new remote to your local repository on your local machine:

```bash
$ git remote add mine git@github.com:<your user name>/rails.git
```

Push to your remote:

```bash
$ git push mine my_new_branch
```

You might have cloned your forked repository into your machine and might want to add the original Rails repository as a remote instead, if that's the case here's what you have to do.

In the directory you cloned your fork:

```bash
$ git remote add rails git://github.com/rails/rails.git
```

Download new commits and branches from the official repository:

```bash
$ git fetch rails
```

Merge the new content:

```bash
$ git checkout master
$ git rebase rails/master
```

Update your fork:

```bash
$ git push origin master
```

If you want to update another branches:

```bash
$ git checkout branch_name
$ git rebase rails/branch_name
$ git push origin branch_name
```


### Issue a Pull Request

Navigate to the Rails repository you just pushed to (e.g. https://github.com/your-user-name/rails) and press "Pull Request" in the upper right hand corner.

Write your branch name in the branch field (this is filled with "master" by default) and press "Update Commit Range".

Ensure the changesets you introduced are included in the "Commits" tab. Ensure that the "Files Changed" incorporate all of your changes.

Fill in some details about your potential patch including a meaningful title. When finished, press "Send pull request". The Rails core team will be notified about your submission.

### Get some Feedback

Now you need to get other people to look at your patch, just as you've looked at other people's patches. You can use the [rubyonrails-core mailing list](http://groups.google.com/group/rubyonrails-core/) or the #rails-contrib channel on IRC freenode for this. You might also try just talking to Rails developers that you know.

### Iterate as Necessary

It’s entirely possible that the feedback you get will suggest changes. Don’t get discouraged: the whole point of contributing to an active open source project is to tap into community knowledge. If people are encouraging you to tweak your code, then it’s worth making the tweaks and resubmitting. If the feedback is that your code doesn’t belong in the core, you might still think about releasing it as a gem.

### Backporting

Changes that are merged into master are intended for the next major release of Rails. Sometimes, it might be beneficial for your changes to propagate back to the maintenance releases for older stable branches. Generally, security fixes and bug fixes are good candidates for a backport, while new features and patches that introduce a change in behavior will not be accepted. When in doubt, it is best to consult a Rails team member before backporting your changes to avoid wasted effort.

For simple fixes, the easiest way to backport your changes is to [extract a diff from your changes in master and apply them to the target branch](http://ariejan.net/2009/10/26/how-to-create-and-apply-a-patch-with-git).

First make sure your changes are the only difference between your current branch and master:

```bash
$ git log master..HEAD
```

Then extract the diff:

```bash
$ git format-patch master --stdout > ~/my_changes.patch
```

Switch over to the target branch and apply your changes:

```bash
$ git checkout -b my_backport_branch 3-2-stable
$ git apply ~/my_changes.patch
```

This works well for simple changes. However, if your changes are complicated or if the code in master has deviated significantly from your target branch, it might require more work on your part. The difficulty of a backport varies greatly from case to case, and sometimes it is simply not worth the effort.

Once you have resolved all conflicts and made sure all the tests are passing, push your changes and open a separate pull request for your backport. It is also worth noting that older branches might have a different set of build targets than master. When possible, it is best to first test your backport locally against the Ruby versions listed in `.travis.yml` before submitting your pull request.

And then... think about your next contribution!

Rails Contributors
------------------

All contributions, either via master or docrails, get credit in [Rails Contributors](http://contributors.rubyonrails.org).
