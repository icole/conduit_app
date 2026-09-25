# Loads the task management prototype's sample data (tasks-spec/*.png) into a
# community: its workstreams, recurring and one-off tasks, a handful of sample
# neighbours in five households, and a few months of completed work so the
# Contribution tab has something to show. +viewer+ gets the prototype's
# "My Tasks". With people: false it loads only the workstreams and tasks,
# unowned and unassigned, for a real community to fill in. Safe to run more
# than once.
class TaskSampleData
  class Refused < StandardError; end

  HOUSEHOLDS = {
    "Sam Santos" => "Santos",
    "Priya Goldberg" => "Goldberg",
    "Miguel Rivera" => "Rivera-Chen",
    "Alex Chen" => "Rivera-Chen",
    "Dana Okafor" => "Okafor",
    "Jordan Nguyen" => "Nguyen-Park",
    "Rae Park" => "Nguyen-Park"
  }.freeze

  # Capacity varies; these neighbours had a lighter stretch.
  LIGHTER_LOAD = [ "Jordan Nguyen", "Rae Park" ].freeze

  HISTORY_WEEKS = 16

  def initialize(community, viewer: nil, people: true)
    @community = community
    @viewer = viewer
    @people = people
  end

  def load!
    if @people && Rails.env.production? && !@community.slug.include?("demo")
      raise Refused, "Sample neighbours only go into demo communities in production (#{@community.slug} isn't one)."
    end

    ActsAsTenant.with_tenant(@community) do
      ApplicationRecord.transaction do
        @today = Time.current.in_time_zone(@community.time_zone).to_date
        people = @people ? create_people : {}
        @viewer ||= User.where(admin: true).order(:id).first || people.fetch("Sam Santos")
        workstreams = create_workstreams(people)
        recurring = create_recurring_tasks(workstreams, people)
        create_one_off_tasks(workstreams)
        if @people
          complete_history(recurring, people)
          RecurringTask.generate_instances!(@today)
          release_this_week(recurring.fetch("Water the greenhouse"), people.fetch("Dana Okafor"))
        else
          RecurringTask.generate_instances!(@today)
        end
      end
    end
  end

  private

  def create_people
    HOUSEHOLDS.to_h do |name, household_name|
      household = Household.find_or_create_by!(name: household_name)
      user = User.find_or_create_by!(email: "#{name.parameterize(separator: '.')}@example.com") do |u|
        u.name = name
        u.password = SecureRandom.base58(24)
        u.household = household
        u.email_verified_at = Time.current
      end
      [ name, user ]
    end
  end

  def create_workstreams(people)
    [
      [ "Garbage & Recycling Coordinator", "permanent", "essential", "Sam Santos",
        "Rolls the community's trash, recycling, and yard-waste bins to the curb for weekly pickup and brings them back." ],
      [ "Garden Health", "permanent", "important", "Priya Goldberg",
        "Keeps the landscaping healthy — watering in dry months, handling pests and pruning, planting, and winterizing spigots." ],
      [ "Garden People Wrangler", "permanent", "nice_to_have", "Miguel Rivera",
        "Organizes the people side of the garden — work parties, raised-bed assignments, compost, and teaching." ],
      [ "Groundskeeper", "permanent", "important", "Alex Chen",
        "Keeps shared paths, decks, gutters, drainage, and outdoor lighting in good shape." ],
      [ "Common House Wrangler", "permanent", "essential", nil,
        "Keeps the Common House clean, stocked, and organized, including shared equipment." ],
      [ "Community Meal Supporter", "permanent", "important", "Dana Okafor",
        "Keeps community meals running smoothly — dietary needs, the meal calendar, and RSVP/cook reminders." ],
      [ "Amenities (Hot Tub, Fire Pit, Fountain)", "permanent", "important", "Jordan Nguyen",
        "Maintains the hot tub, fire pit, and fountain and keeps those areas clean and safe." ],
      [ "Vendor Coordinator", "permanent", "nice_to_have", "Rae Park",
        "Finds, hires, and manages outside contractors for shared-space maintenance and keeps a trusted-vendor list." ],
      [ "#{@community.name} Ambassador", "permanent", "essential", nil,
        "Welcomes visitors and prospective members, and represents the community to its neighbours." ],
      [ "Front yard project", "ad_hoc", "important", "Miguel Rivera",
        "Replant the front beds and put in a bench before summer." ],
      [ "High water bills", "ad_hoc", "nice_to_have", "Rae Park",
        "Work out why the water bills doubled and what to do about it." ]
    ].to_h do |name, type, priority, owner, description|
      workstream = Workstream.find_or_create_by!(name: name) do |w|
        w.workstream_type = type
        w.priority = priority
        w.owners = [ people[owner] ].compact
        w.description = description
      end
      [ name, workstream ]
    end
  end

  def create_recurring_tasks(workstreams, people)
    viewer = @viewer if @people
    [
      [ "Garbage & Recycling Coordinator", "Take out garbage & recycling", "weekly", 15, nil, viewer ],
      [ "Common House Wrangler", "Clean shared kitchen", "weekly", 45, "essential", nil ],
      [ "Common House Wrangler", "Restock common house pantry", "weekly", 40, "important", viewer ],
      [ "Garden Health", "Water the greenhouse", "weekly", 20, nil, people["Dana Okafor"] ],
      [ "Garden Health", "Compost turnover", "biweekly", 45, nil, people["Priya Goldberg"] ],
      [ "Groundskeeper", "Mow common lawn", "weekly", 90, nil, people["Alex Chen"] ],
      [ "Groundskeeper", "Organize the tool shed", "monthly", 90, "nice_to_have", nil ],
      [ "Garden People Wrangler", "Plan the garden work party", "monthly", 60, nil, people["Miguel Rivera"] ],
      [ "Community Meal Supporter", "Update the meal calendar", "weekly", 20, nil, people["Sam Santos"] ],
      [ "Amenities (Hot Tub, Fire Pit, Fountain)", "Check and clean the hot tub", "weekly", 30, nil, people["Jordan Nguyen"] ],
      [ "Vendor Coordinator", "Review contractor invoices", "monthly", 45, nil, people["Rae Park"] ]
    ].to_h do |workstream_name, title, frequency, minutes, priority, person|
      workstream = workstreams.fetch(workstream_name)
      recurring = workstream.recurring_tasks.find_or_create_by!(title: title) do |r|
        r.frequency = frequency
        r.estimated_minutes = minutes
        r.priority = priority
        r.default_responsible_user = person
        r.created_by = @viewer
        r.starts_on = @today - HISTORY_WEEKS.weeks
      end
      [ title, recurring ]
    end
  end

  def create_one_off_tasks(workstreams)
    [
      [ "Buy supplies for work party", "Front yard project", 20, 4 ],
      [ "Draft quarterly budget note", "High water bills", 45, 8 ]
    ].each do |title, workstream_name, minutes, due_in|
      workstreams.fetch(workstream_name).tasks.find_or_create_by!(title: title) do |task|
        task.user = @viewer
        task.assigned_to_user = @viewer if @people
        task.estimated_minutes = minutes
        task.due_date = @today + due_in
      end
    end
  end

  # Past periods' instances, completed by whoever was responsible. Weeks a
  # lighter-load neighbour released were covered by Sam; tasks nobody holds
  # were picked up by a rotating volunteer.
  def complete_history(recurring_tasks, people)
    volunteers = people.values
    coverer = people.fetch("Sam Santos")

    recurring_tasks.each_value do |recurring|
      person = recurring.default_responsible_user
      date = @today - HISTORY_WEEKS.weeks
      index = 0
      while (period = recurring.period_for(date)).end < @today
        task = recurring.instance_for(date)
        if task && !task.completed?
          done_by = if person.nil?
            volunteers[index % volunteers.size]
          elsif LIGHTER_LOAD.include?(person.name) && index.odd?
            task.released_by = person
            task.released_at = period.begin.in_time_zone(@community.time_zone).change(hour: 9)
            coverer
          else
            person
          end
          task.update!(assigned_to_user: done_by, status: "completed", completed_by: done_by,
                       completed_at: period.end.in_time_zone(@community.time_zone).change(hour: 18))
        end
        date = period.end + 1
        index += 1
      end
    end
  end

  # Released straight onto the record: sample data shouldn't post to chat.
  def release_this_week(recurring, person)
    task = recurring.instance_for(@today)
    return unless task && task.assigned_to_user_id == person.id

    task.update!(assigned_to_user: nil, released_by: person, released_at: Time.current)
  end
end
