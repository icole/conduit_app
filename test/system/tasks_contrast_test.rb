require "application_system_test_case"

# Every piece of text on the Tasks tabs and a workstream page meets WCAG AA
# (4.5:1), at desktop and phone widths. The theme's warning/info/success/error
# colours are too light to use as text on the page background (yellow was
# 1.8:1), so text uses the darker *-ink shades instead.
class TasksContrastTest < ApplicationSystemTestCase
  AUDIT = File.read(Rails.root.join("test/support/contrast_audit.js")).strip

  setup do
    ActsAsTenant.with_tenant(communities(:crow_woods)) do
      Task.delete_all
      RecurringTask.with_discarded.delete_all
      Workstream.delete_all
      TaskSampleData.new(communities(:crow_woods), viewer: users(:admin_user)).load!
      # someone covering for someone else, so that label is on the page too
      Task.find_by!(title: "Water the greenhouse").claim!(users(:admin_user))
    end
    sign_in_as(users(:admin_user))
  end

  def low_contrast_text(root)
    page.evaluate_script("(#{AUDIT})(#{root.to_json}, 4.5)").map { |row| "#{row['ratio']}:1 “#{row['text']}” (#{row['classes']})" }.uniq
  end

  [ [ "desktop", 1400 ], [ "phone", 375 ] ].each do |size, width|
    test "text on the Tasks pages is readable on #{size}" do
      page.driver.browser.manage.window.resize_to(width, 1400)
      failures = []

      %w[my available coverage contribution].each do |tab|
        visit tasks_url(tab: tab)
        assert_selector "nav[aria-label='Task views']"
        failures += low_contrast_text("#tasks_content").map { |f| "#{tab}: #{f}" }
      end

      project = ActsAsTenant.with_tenant(communities(:crow_woods)) { Workstream.find_by!(name: "Front yard project") }
      visit workstream_url(project)
      failures += low_contrast_text("main").map { |f| "workstream: #{f}" }

      assert_empty failures, "Text below 4.5:1 on #{size}:\n#{failures.join("\n")}"
    ensure
      page.driver.browser.manage.window.resize_to(1400, 1400)
    end
  end
end
