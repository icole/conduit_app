require "test_helper"

class AvatarHelperTest < ActionView::TestCase
  test "someone with a photo shows the photo, with their initials ready if it fails to load" do
    user = User.new(name: "Jane Smith", avatar_url: "https://example.com/jane.jpg")
    render inline: "<%= user_avatar(user) %>", locals: { user: user }

    assert_select ".avatar.avatar-placeholder[data-controller=avatar]" do
      assert_select "img[src='https://example.com/jane.jpg'][data-action='error->avatar#fallback']"
      assert_select "span[hidden][data-avatar-target=initials]", text: "JS"
    end
  end

  test "someone without a photo shows their initials" do
    user = User.new(name: "Mike Davis")
    render inline: "<%= user_avatar(user, size: 'w-10', initials_class: 'bg-primary text-primary-content') %>", locals: { user: user }

    assert_select ".avatar .w-10.bg-primary", text: "MD"
    assert_select "img", count: 0
  end
end
