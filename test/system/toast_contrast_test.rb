require "application_system_test_case"

# Toasts (layouts/_toast) meet WCAG AA like the rest of the app: the green
# success toast with its Undo button, and the red error toast.
class ToastContrastTest < ApplicationSystemTestCase
  AUDIT = File.read(Rails.root.join("test/support/contrast_audit.js")).strip

  def low_contrast_text(root)
    page.evaluate_script("(#{AUDIT})(#{root.to_json}, 4.5)").map { |row| "#{row['ratio']}:1 “#{row['text']}” (#{row['classes']})" }.uniq
  end

  test "success (with Undo) and error toasts are readable" do
    sign_in_as(users(:one))
    visit tasks_url(tab: "my")
    find("button[aria-label='Mark “#{tasks(:received_task).title}” done']").click
    assert_selector "#undo-notification", text: "Undo"
    assert_empty low_contrast_text("#undo-notification")

    visit new_workstream_url # admins only: members are sent back with an error
    assert_selector "[data-toast][role=alert]"
    assert_empty low_contrast_text("#toasts")
  end
end
