# Ruby on Rails Contribution Guide

Ruby on Rails is a volunteer effort. We encourage you to pitch in. [Join the team](http://contributors.rubyonrails.org)!

Please note that *we only accept bug reports here*. No feature requests or questions about Rails.

If you have a question about how to use Ruby on Rails, [ask the Rails-talk mailing list](https://groups.google.com/forum/?fromgroups#!forum/rubyonrails-talk).

If you have a change or new feature in mind, [suggest it on the Rails-core mailing list](https://groups.google.com/forum/?fromgroups#!forum/rubyonrails-core) and start writing code. Check out the [Contributing to Ruby on Rails guide](http://edgeguides.rubyonrails.org/contributing_to_ruby_on_rails.html) for a comprehensive introduction.

# Contributing to Rails via Code

## Adding new Features or Bugfixes

If you have a bug [Create an issue](https://github.com/rails/rails/issues/new). If you want to code a new feature you can ask the [mailing list first](https://groups.google.com/forum/?fromgroups#!forum/rubyonrails-core), but consider that most features are dependent on implementation, so often times just writing the feature and contributing a [pull request](https://help.github.com/articles/using-pull-requests) will give you the best feedback.

Once you've decided to make changes you can fork [rails/rails](https://github.com/rails/rails) on github and then clone your fork to your local machine. Make sure you're using the correct branch, master is the pre-release of Rails. 1-x-stable refers to  Rails 1.x. e.g. 1-2-stable means Rails 1.2.

Now that you have everything on your computer, write the code and include a test covering your changes. Make sure that the code you add is not using internals from another library. For example: Action Pack, Active Record, etc. should have no knowledge of Railties. You can use integration points when needed such as middleware and [initializers](https://github.com/rails/rails/blob/master/actionmailer/lib/action_mailer/railtie.rb).

Review your changes in git making sure to remove any un-needed whitespace such as trailing spaces, or duplicate new lines and double check your indentation is correct.

Once you are happy with your changes commit them and ensure tests pass in any libraries you changed. Add a line in the [CHANGELOG](https://github.com/rails/rails/blob/master/CHANGELOG.md) summarizing your changes under the appropriate release and under the "Features" heading.

Finally send a [pull request](https://help.github.com/articles/using-pull-requests) with a descriptive title and summary. If you are contributing a bug fix, explain what the bug was, how it affected programmers, and how the fix will affect programmers. Link to the appropriate issues using Github issue pound notation. If you are submitting a new feature, explain why you wanted the feature, why other programmers would want the same feature, why Rails should support the feature moving into the future. Be patient and understand that even for desired features you may need to make multiple revisions before the code can be merged into Rails. Telling a good story to help those not as familiar with you code can be the difference between a :+1: and a :-1:.

Once you have submitted your pull request it may be some time before you hear from someone. Do not worry, this is normal. The rails issue team is extremely busy and will get to you as soon as they can. Once they do comment on your PR it is normal for them to request changes or ask questions, please take time to craft detailed responses remembering that this is not the only issue they are looking at, the more descriptive you can be the better.  If you are uncertain about an implementation decision please invite other programmers to review your pull request. You can help the Rails Issue team and other Rails contributers by [Triaging Issues](#issue-triage).


## Contributing to Docs

Documentation is hugely valuable to Rails. Documentation comes in our [API docs](http://api.rubyonrails.org/) as well as our [Rails Guides](http://guides.rubyonrails.org/). To make contributing documentation easier you can clone [docrails](https://github.com/lifo/docrails) and make changes directly

    $ git clone git@github.com:lifo/docrails.git

When you are happy with your changes, commit them to git and then push to master:

    $ git push origin master

Any commits to [Docrails](https://github.com/lifo/docrails) will be reviewed but do not require a pull request. [Docrails](https://github.com/lifo/docrails) is periodically merged into Rails master. If you are contributing to the guides please follow the [Rails Guides Style](http://guides.rubyonrails.org/ruby_on_rails_guides_guidelines.html).

## Rebasing and Merge Conflicts

After a feature request or bugfix is submitted it is likely that you will need a rebase. This means that Rails head has changed since you last forked it and those changes caused a merge conflict that you need to fix. To start off add rails/rails as a remote of "upstream" to your git fork:

    $ git remote add upstream git@github.com:rails/rails.git

Now run this command to pull the latest changes from master onto your fork:

    $ git pull --rebase upstream master

You can rebase against upstream while you are developing your feature or bug fix to help avoid merge conflicts. If you submit a PR and someone responds with "rebase needed" it means you need to follow these steps and fix any conflicts you encounter.

## Squashing Commits

While developing your fix or feature you may need to break it up into several different commits, depending on the size and nature of your changes the core team may ask you to "squash" your commits to help keep git history clear. If they want you to squash all of your commits into one commit, you can do this using `$ git rebase -i`. First rebase against upstream master, then if you need to squash the last 4 commits into 1 you would run

    $ git rebase -i HEAD~3

This will open up a text editor and list the last three commits (specified by the number after the `~`). It might look something like this:

    pick 4714c8a edits a little bit CONTRIBUTING.md [ci skip]
    pick 84a1e40 removes spurious quote
    pick a95ddf6 Roll contrib guide link into feature request guidance

To squash those all into one commit change "pick" to "squash" in the last two:

    pick 4714c8a edits a little bit CONTRIBUTING.md [ci skip]
    squash 84a1e40 removes spurious quote
    squash a95ddf6 Roll contrib guide link into feature request guidance

When you close the file, git will try to rebase those three commits into one. If you accidentally do something wrong in a rebase, remember you can always go back, using the `$ git reflog`.


# Contributing outside of Code

## Issue Triage

As bugs are filed the Rails team needs to verify that they actually exist, and what should be done to fix them. This is a time consuming job, and the more people helping to do this the better. You can help Rails by reading over issues as they come in and triaging them.

* Look at existing bugs and make sure they have all needed information:
  * The bug is reproducible? What are the steps to reproduce?
  * Does the bug happen across different system setups or rubies?

* You can help close fixed bugs by testing old tickets to see if they are happening.
* To remove duplicate bug reports:
  * ping someone on the core team
  * on the duplicate issue, reference the original issue. e.g. "@indirect, @hone, @wycats: this is duplicate of issue #42"
* Fixing an issue is similar adding a new feature:
  * Discuss the fix on the existing issue.
  * Make sure you're using the correct branch.
    * master - prerelease of Rails
    * 1-x-stable - Rails 1.x. e.g. 1-2-stable means Rails 1.2.
  * Write the code and include a test covering your changes.
  * Put a line in the [CHANGELOG](https://github.com/rails/rails/blob/master/CHANGELOG.md) summarizing your changes under the appropriate release and under the "Bugfixes" heading.
  * Send a [pull request](https://help.github.com/articles/using-pull-requests)

* You can help report bugs by filing them here: <https://github.com/rails/rails/issues/new>
* You can look through the existing bugs here: <https://github.com/rails/rails/issues>

When there are too many issues, some important ones can get lost or forgotten, by helping to keep an eye on issues, and by helping to remove stale issues you are doing a huge service to your community. If you wish to help triage issues but don't know where to get started, sign up to receive one issue a day using the [Issue Triage App](http://issuetriage.herokuapp.com/).

## Community

* You can help us answer questions our users have on our [issues section](https://github.com/rails/rails/issues) or [stackoverflow](http://stackoverflow.com/questions/tagged/rails).
* Consider joining a local Rails or Ruby user group such as [SeattleRB](http://www.seattlerb.org/) or [Austin on Rails](http://austinonrails.org/).
* Consider volunteering to mentor or teach beginners. Having Ruby and Rails install-fests is a great way to introduce people to the framework. Working with beginners may help you find documentation or bug fixes that you can [contribute to Rails](http://contributors.rubyonrails.org).
* Test the pre-releases of Rails with your current projects
* Pair on a Rails issue with another developer to help share knowledge