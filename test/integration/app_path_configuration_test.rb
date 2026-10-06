require "test_helper"

# Each app's path configuration decides which pages open as sheets. A page
# whose whole job is one form you fill in or back out of (new, edit,
# reschedule, sign up to cook, RSVP, a settings form, deleting your account)
# is a sheet; anything you read or browse is a full screen. Both apps agree.
class AppPathConfigurationTest < ActiveSupport::TestCase
  CONFIGS = {
    "Android" => Rails.root.join("android/app/src/main/assets/json/path-configuration.json"),
    "iOS" => Rails.root.join("ios/Conduit/Conduit/Configuration/path-configuration.json")
  }.freeze

  SHEETS = %w[/meals/new /tasks/9/edit /tasks/new?workstream_id=3 /tasks/9/edit?return_to=%2Fworkstreams%2F3
              /calendar_events/new /calendar_events/abc/edit /notifications
              /meals/5/reschedule /meals/5/cook /meals/5/cook?role=head_cook /meals/5/rsvp?user_id=7
              /dues/settings /account/delete].freeze

  FULL_SCREENS = %w[/tasks /tasks?tab=my /meals/5 /meals /documents/3/edit /dues /account
                    /notifications/5 /meals/my_meals].freeze

  # As Hotwire applies them: every matching rule, later ones winning
  def context_for(config, path)
    JSON.parse(config.read)["rules"].each_with_object({}) do |rule, merged|
      merged.merge!(rule["properties"]) if rule["patterns"].any? { |pattern| Regexp.new(pattern, Regexp::IGNORECASE).match?(path) }
    end["context"]
  end

  CONFIGS.each do |app, config|
    test "#{app}: forms open as sheets, with or without a query string" do
      SHEETS.each { |path| assert_equal "modal", context_for(config, path), path }
    end

    test "#{app}: pages you read or browse stay full screen" do
      FULL_SCREENS.each { |path| assert_includes [ nil, "default" ], context_for(config, path), path }
    end
  end
end
