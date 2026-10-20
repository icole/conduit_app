require "application_system_test_case"

# The hot tub case: someone can't keep doing a recurring job, hands it off,
# and someone else finds it in Available and takes it on.
class RecurringHandoffTest < ApplicationSystemTestCase
  test "handing a job off from My Tasks and taking it on from Available" do
    recurring = recurring_tasks(:garbage_night)
    task = recurring.instance_for
    sign_in_as(users(:one))
    visit tasks_url(tab: "my")

    within("#task_#{task.id}") do
      find("[aria-label='More actions']").click
      accept_confirm(/Hand off “Take out garbage & recycling” for good\?/) { click_button "Hand it off for good" }
    end
    assert_text "Handed off. We've asked who can take it on."
    assert_no_selector "#my-work", text: "Take out garbage & recycling"

    Capybara.reset_session!
    sign_in_as(users(:two))
    visit tasks_url(tab: "available")
    within("#needs-someone-new") do
      assert_text "Handed off by Jane"
      accept_confirm(/It comes to you weekly from now on/) { click_button "Take it on" }
    end
    assert_text "“Take out garbage & recycling” is yours from now on."
    assert_no_selector "#needs-someone-new"
    assert_equal [ users(:two) ], recurring.reload.responsibles
  end
end
