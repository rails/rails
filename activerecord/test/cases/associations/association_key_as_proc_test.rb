require 'cases/helper'
require 'models/post'
require 'models/comment'

class AssociationKeyAsProcTest < ActiveRecord::TestCase
  def setup
    @post = Post.create :title => 'Some post', :body => 'Post body'
    @parent = Comment.create :post => @post, :body => "I'm parent"
    @child1 = Comment.create :post => @post, :body => "I'm child#1", :parent => @parent
    @child2 = Comment.create :post => @post, :body => "I'm child#2", :parent => @parent
    @subchild = Comment.create :post => @post, :body => "I'm subchild", :parent => @child1
  end

  def test_loading_an_association_using_proc_for_pk
    siblings_and_children = @child1.siblings_and_children

    assert siblings_and_children.include?(@child2)
    assert siblings_and_children.include?(@subchild)
  end

  def test_loading_an_association_using_proc_for_pk_with_include
    comment = Comment.where(:body => @child1.body).includes(:siblings_and_children).first
    assert_no_queries { comment.siblings_and_children.length }
  end

  def test_loading_an_association_using_proc_for_pk_with_join
    assert_raises(ActiveRecord::NonScalarPrimaryKeyError) {
      Comment.where(:body => @child1.body).joins(:siblings_and_children).first
    }
  end
end
