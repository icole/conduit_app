require "test_helper"

# Every message (saved, failed, or "Task deleted" with Undo) is the same
# toast, in the same place.
class ToastTest < ActionView::TestCase
  test "a notice and an alert are toasts, success and error" do
    controller.flash[:notice] = "Saved."
    controller.flash[:alert] = "Couldn't save."
    render partial: "layouts/flash_messages"

    assert_select "[data-toast][role=status].alert-success", text: /Saved\./
    assert_select "[data-toast][role=alert].alert-error", text: /Couldn't save\./
    assert_select "[data-toast] button[aria-label=Close]", 2
    assert_select "[data-toast][data-flash-delay-value='5000']", 2
  end

  test "Undo is the same toast with an Undo button, and stays up longer" do
    controller.flash[:notice_with_undo] = { message: "Task deleted.", undo_path: "/tasks/1/restore" }
    render partial: "layouts/undo_notification"

    assert_select "#undo-notification[data-toast][role=status].alert-success", text: /Task deleted\./ do
      assert_select "form[action='/tasks/1/restore'] button", text: "Undo"
      assert_select "button[aria-label=Close]"
    end
    assert_select "[data-toast][data-flash-delay-value='8000']"
  end
end
