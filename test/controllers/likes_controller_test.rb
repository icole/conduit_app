require "test_helper"

class LikesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user1 = users(:one)
    @post = posts(:two)
    @like = likes(:one)
    sign_in_user({ uid: @user1.uid, name: @user1.name, email: @user1.email })
  end

  test "should get create" do
    assert_difference("Like.count", 1) do
      post post_likes_url(post_id: @post.id, user_id: @user1.id)
    end

    assert_redirected_to dashboard_index_url
  end

  test "should get destroy" do
    assert_difference("Like.count", -1) do
      delete post_like_url(id: @like.id, post_id: @like.likeable_id)
    end

    assert_redirected_to dashboard_index_url
  end
end
