require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user1 = users(:one)
    @post = posts(:one)
    sign_in_user({ uid: @user1.uid, name: @user1.name, email: @user1.email })
  end

  test "should get create" do
    assert_difference("Post.count", 1) do
      post posts_url, params: { post: { content: "This is a test post" } }
    end

    assert_redirected_to dashboard_index_url
  end

  test "should get update" do
    get posts_update_url
    assert_response :success
  end

  test "should get destroy" do
    assert_difference("Post.count", 1) do
      post posts_url, params: { post: { content: "This is a test post" } }
    end

    assert_redirected_to dashboard_index_url
  end
end
