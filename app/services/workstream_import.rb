# Applies a workstream plan (see db/data/crow_woods_workstreams.yml) to a
# community: renames, creates and updates workstreams (type, priority,
# description, owners) and their recurring tasks, and removes listed leftovers.
# Owners are matched by first name. A workstream that lists no owners keeps the
# ones members set in the app, and its tasks keep who's responsible, so the
# checked-in plan doesn't need anyone's name. Returns a list of the changes
# made; with dry_run: true it reports them and rolls everything back. Safe to
# run again.
class WorkstreamImport
  class Error < StandardError; end

  def initialize(community, data)
    @community = community
    @data = data
    @changes = []
  end

  def apply!(dry_run: false)
    ActsAsTenant.with_tenant(@community) do
      @today = Time.current.in_time_zone(@community.time_zone).to_date
      owners = resolve_owners # fails before anything is written

      ApplicationRecord.transaction do
        rename_workstreams
        rename_recurring_tasks
        @data.fetch("workstreams", []).each { |plan| apply_workstream(plan, owners.fetch(plan["name"])) }
        remove_recurring_tasks
        remove_unstarted_tasks
        raise ActiveRecord::Rollback if dry_run
      end
    end
    @changes
  end

  private

  def resolve_owners
    people = User.all.to_a
    missing = []
    owners = @data.fetch("workstreams", []).to_h do |plan|
      next [ plan["name"], nil ] unless plan.key?("owners")

      users = Array(plan["owners"]).map do |first_name|
        matches = people.select { |user| user.name.to_s.split.first&.casecmp?(first_name) }
        missing << "#{first_name} (#{matches.size} matches, for #{plan['name']})" unless matches.one?
        matches.first
      end
      [ plan["name"], users ]
    end
    Array(@data["workstreams"]).each do |plan|
      Array(plan["recurring_tasks"]).each do |task|
        Array(task["responsible"]).each do |person|
          next if Array(plan["owners"]).any? { |name| name.casecmp?(person) }

          missing << "#{person} is responsible for #{task['title']} but isn't an owner of #{plan['name']}"
        end
      end
    end
    raise Error, "Can't match owners: #{missing.join('; ')}" if missing.any?

    owners
  end

  def rename_workstreams
    @data.fetch("rename_workstreams", {}).each do |from, to|
      workstream = Workstream.find_by(name: from)
      next if workstream.nil? || Workstream.exists?(name: to)

      workstream.update!(name: to)
      @changes << "rename workstream #{from} -> #{to}"
    end
  end

  def rename_recurring_tasks
    @data.fetch("rename_recurring_tasks", {}).each do |from, to|
      RecurringTask.where(title: from).find_each do |recurring|
        recurring.update!(title: to)
        @changes << "rename recurring task #{from} -> #{to}"
      end
    end
  end

  def apply_workstream(plan, owners)
    workstream = Workstream.find_or_initialize_by(name: plan["name"])
    created = workstream.new_record?
    workstream.assign_attributes(
      workstream_type: plan["type"],
      priority: plan["priority"] || (plan["type"] == "governance" ? "essential" : "important"),
      description: compose_description(plan)
    )
    if created || workstream.changed?
      @changes << "#{created ? 'create' : 'update'} workstream #{workstream.name} (#{workstream.changed.join(', ')})"
      workstream.save!
    end

    if owners && workstream.owners.to_a.sort_by(&:id) != owners.sort_by(&:id)
      workstream.owners = owners
      @changes << "set owners of #{workstream.name}: #{owners.map(&:name).join(', ').presence || 'none'}"
    end

    current_owners = owners || workstream.owners.to_a
    Array(plan["recurring_tasks"]).each do |task_plan|
      # Named people (one or a list), or else as many owners as it needs
      named = Array(task_plan["responsible"])
      responsibles = if named.any?
        named.filter_map { |name| current_owners.find { |user| user.name.split.first.casecmp?(name) } }
      else
        current_owners.first(task_plan["people_needed"] || 1)
      end
      apply_recurring_task(workstream, task_plan, responsibles, keep_responsible: owners.nil?)
    end
  end

  def compose_description(plan)
    parts = [ plan["description"].to_s.strip ]
    parts << "Time commitment: #{plan['time_commitment']}" if plan["time_commitment"].present?
    if plan["also"].present?
      parts << "Also, as needed or seasonally:\n" + plan["also"].map { |line| "• #{line}" }.join("\n")
    end
    parts.compact_blank.join("\n\n")
  end

  def apply_recurring_task(workstream, plan, responsibles, keep_responsible: false)
    recurring = RecurringTask.find_or_initialize_by(title: plan["title"])
    created = recurring.new_record?
    recurring.assign_attributes(
      workstream: workstream,
      description: plan["description"],
      frequency: plan["frequency"],
      estimated_minutes: plan["minutes"]
    )
    recurring.people_needed = plan["people_needed"] if plan["people_needed"]
    new_people = (created || !keep_responsible) && recurring.responsible_ids.sort != responsibles.map(&:id).sort
    recurring.created_by ||= responsibles.first || User.where(admin: true).order(:id).first
    if plan["first_period_starts"].present?
      recurring.starts_on = most_recent(plan["first_period_starts"])
    elsif created
      recurring.starts_on = @today
    end
    return unless created || recurring.changed? || new_people

    changed = recurring.changed + (new_people ? [ "responsibles" ] : [])
    @changes << "#{created ? 'create' : 'update'} recurring task #{recurring.title} in #{workstream.name} (#{changed.join(', ')})"
    recurring.responsibles = responsibles if new_people
    recurring.save!
    sync_open_instances(recurring) unless created
  end

  # "11-01" -> the latest Nov 1 on or before today
  def most_recent(month_day)
    month, day = month_day.split("-").map(&:to_i)
    date = Date.new(@today.year, month, day)
    date > @today ? date.prev_year : date
  end

  # This period's open work picks up the new title, time and, if nobody is on
  # it yet, the people now responsible.
  def sync_open_instances(recurring)
    recurring.instances.open.find_each do |task|
      task.title = recurring.title
      task.description = recurring.description
      task.estimated_minutes = recurring.estimated_minutes
      if task.assignees.empty? && !task.released_by_id
        task.people_needed = recurring.people_needed
        task.assignees = recurring.responsibles.to_a
      end
      task.save! if task.changed?
    end
  end

  def remove_recurring_tasks
    RecurringTask.where(title: @data.fetch("remove_recurring_tasks", [])).find_each do |recurring|
      recurring.discard
      @changes << "remove recurring task #{recurring.title} (and its open work)"
    end
  end

  def remove_unstarted_tasks
    Task.open.where(title: @data.fetch("remove_unstarted_tasks", []), recurring_task_id: nil).where.missing(:task_assignments).find_each do |task|
      task.discard
      @changes << "remove unstarted task #{task.title}"
    end
  end
end
