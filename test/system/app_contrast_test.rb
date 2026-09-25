require "application_system_test_case"

# Text across the app meets WCAG AA (4.5:1) at desktop and phone widths.
# The cupcake theme's colours are adjusted in app/assets/tailwind/application.css
# so labels, greys, red/green buttons and coloured text all pass.
class AppContrastTest < ApplicationSystemTestCase
  AUDIT = File.read(Rails.root.join("test/support/contrast_audit.js")).strip

  SIGNED_OUT = %w[/login /register /password_reset/new /privacy /terms /communities/new].freeze

  def signed_in_pages
    ids = ActsAsTenant.with_tenant(communities(:crow_woods)) do
      { meal: Meal.first.id, decision: Decision.first.id, document: Document.first&.id, email_log: EmailLog.first&.id }
    end
    [ "/", "/meals", "/meals/calendar", "/meals/my_meals", "/meals/new", "/meals/#{ids[:meal]}",
      "/meal_schedules", "/meal_schedules/new", "/decisions", "/decisions/new", "/decisions/#{ids[:decision]}",
      "/documents", ids[:document] && "/documents/#{ids[:document]}", "/calendar", "/notifications",
      "/users", "/users/#{users(:regular_user).id}/edit", "/households", "/households/new",
      "/email_logs", ids[:email_log] && "/email_logs/#{ids[:email_log]}", "/dues", "/dues/settings",
      "/account", "/account/delete", "/profile/edit", "/invitations", "/invitations/new",
      "/tasks?view=active", "/tasks/new", "/workstreams/new" ].compact
  end

  def low_contrast_text(path)
    visit path
    page.evaluate_script("(#{AUDIT})('body', 4.5)").map { |row| "#{path}: #{row['ratio']}:1 “#{row['text'][0, 40]}” (#{row['classes'][0, 70]})" }
  end

  [ [ "desktop", 1400 ], [ "phone", 375 ] ].each do |size, width|
    test "text across the app is readable on #{size}" do
      page.driver.browser.manage.window.resize_to(width, 1400)
      failures = SIGNED_OUT.flat_map { |path| low_contrast_text(path) }

      sign_in_as(users(:admin_user))
      failures += signed_in_pages.flat_map { |path| low_contrast_text(path) }

      assert_empty failures.uniq, "Text below 4.5:1 on #{size} (#{failures.uniq.size}):\n#{failures.uniq.join("\n")}"
    ensure
      page.driver.browser.manage.window.resize_to(1400, 1400)
    end
  end
end
