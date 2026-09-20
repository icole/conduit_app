# frozen_string_literal: true

require "test_helper"

# Chores were removed; the routes and models must be gone.
class ChoresRemovedTest < ActionDispatch::IntegrationTest
  test "chore routes no longer exist" do
    get "/chores"
    assert_response :not_found

    get "/chores/bulk_import"
    assert_response :not_found
  end

  test "chore models are gone" do
    %i[Chore ChoreAssignment ChoreCompletion].each do |name|
      assert_not Object.const_defined?(name), "#{name} should be removed"
    end
  end
end
