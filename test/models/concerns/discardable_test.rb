# frozen_string_literal: true

require "test_helper"

class DiscardableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @post = posts(:one)
    Current.user = @user
  end

  teardown do
    Current.user = nil
  end

  test "discard sets discarded_at timestamp" do
    assert_nil @post.discarded_at
    @post.discard
    assert_not_nil @post.discarded_at
  end

  test "discard sets deleted_by to Current.user" do
    @post.discard
    assert_equal @user, @post.deleted_by
  end

  test "discard without Current.user leaves deleted_by nil" do
    Current.user = nil
    @post.discard
    assert_nil @post.deleted_by
  end

  test "soft deleted records are excluded from default scope" do
    post_id = @post.id
    @post.discard
    refute Post.exists?(post_id)
    assert Post.with_discarded.exists?(post_id)
  end

  test "soft_delete is aliased to discard" do
    @post.soft_delete
    assert @post.discarded?
  end

  test "soft_deleted? is aliased to discarded?" do
    refute @post.soft_deleted?
    @post.discard
    assert @post.soft_deleted?
  end

  test "restore is aliased to undiscard" do
    @post.discard
    assert @post.discarded?
    @post.restore
    refute @post.discarded?
  end

  test "with_discarded scope includes soft deleted records" do
    post_id = @post.id
    @post.discard
    refute Post.exists?(post_id)
    assert Post.with_discarded.exists?(post_id)
  end

  test "only_discarded scope returns only soft deleted records" do
    other_post = posts(:two)
    @post.discard

    discarded_ids = Post.only_discarded.pluck(:id)
    assert_includes discarded_ids, @post.id
    refute_includes discarded_ids, other_post.id
  end

  test "created_by is set on create for models with user association" do
    new_post = @user.posts.create!(content: "Test post content")
    assert_equal @user, new_post.created_by
  end

  test "cascade_discard soft deletes associated comments" do
    comment = @post.comments.create!(content: "Test comment", user: @user)
    refute comment.discarded?

    @post.discard

    comment.reload
    assert comment.discarded?
  end

  test "undiscard restores cascaded comments" do
    comment = @post.comments.create!(content: "Test comment", user: @user)
    @post.discard
    assert comment.reload.discarded?

    @post.undiscard

    comment.reload
    refute comment.discarded?
  end
end
