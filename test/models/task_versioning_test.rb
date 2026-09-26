# frozen_string_literal: true

require "test_helper"

# Tasks carry a lot of provenance questions ("who asked for this?", "who
# reassigned it?"), so their changes are audited.
class TaskVersioningTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:one)
  end

  def build_task
    Task.new(title: "Fix the gate latch", workstream: workstreams(:general), user: users(:one), status: "backlog")
  end

  test "creating a task records a create version" do
    task = build_task

    assert_difference "PaperTrail::Version.where(item_type: 'Task').count", 1 do
      task.save!
    end
    assert_equal "create", task.versions.last.event
  end

  test "changing a task records what it was before" do
    original_title = @task.title
    @task.update!(title: "Renamed")

    version = @task.versions.last
    assert_equal "update", version.event
    assert_equal original_title, version.reify.title
  end

  test "reassigning a task is recorded" do
    @task.update!(assigned_to_user_id: users(:two).id)

    assert_equal "update", @task.versions.last.event
    assert_nil @task.versions.last.reify.assigned_to_user_id
  end

  test "soft deleting a task is recorded rather than lost" do
    assert_difference "PaperTrail::Version.where(item_type: 'Task').count", 1 do
      @task.discard
    end
    assert_nil @task.versions.last.reify.discarded_at
  end

  test "the acting user is recorded when one is set" do
    PaperTrail.request(whodunnit: users(:two).id.to_s) do
      @task.update!(title: "Changed by someone")
    end

    assert_equal users(:two).id.to_s, @task.versions.last.whodunnit
  end
end
