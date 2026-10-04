# The community App Store and Play reviewers sign in to (CON-66): active,
# with chat on, a reviewer account, and neighbours who cook, RSVP, share the
# chores and chat. #reset! runs weekly (DemoResetJob) to clear what reviewers
# and testers added and put the sample content back. The reviewer account
# and the neighbours are kept, so their IDs (and Stream users) stay the same.
class DemoCommunity
  SLUG = "demo".freeze
  NAME = "Demo Community".freeze
  DOMAIN = "demo.conduitcoho.app".freeze
  EMAIL = "demo@conduitcoho.app".freeze
  REVIEWER_NAME = "Demo User".freeze

  MEALS = [
    [ "Lentil soup and fresh bread", "Sam Santos" ],
    [ "Tacos with all the fixings", "Priya Goldberg" ],
    [ "Garden pasta and salad", "Dana Okafor" ]
  ].freeze

  CHAT = [
    [ "Priya Goldberg", "Morning all! The tomatoes in bed 3 are ripe, help yourselves." ],
    [ "Sam Santos", "Reminder: the green bin goes out tonight. It's my week." ],
    [ "Dana Okafor", "Thanks to everyone who came to Sunday's dinner. Leftover soup is in the common house fridge." ]
  ].freeze

  # No default password: this repository is public
  def initialize(password:, slug: SLUG, domain: DOMAIN, name: NAME)
    raise ArgumentError, "the demo account needs a password (DEMO_USER_PASSWORD)" if password.blank?
    raise ArgumentError, "#{slug} isn't a demo community" unless slug.include?("demo")

    @password = password
    @slug = slug
    @domain = domain
    @name = name
  end

  def ensure!
    community = set_up_community
    ActsAsTenant.with_tenant(community) do
      reviewer = set_up_reviewer
      seed(community, reviewer) unless Meal.exists?
    end
    community
  end

  def reset!
    community = set_up_community
    ActsAsTenant.with_tenant(community) do
      reviewer = set_up_reviewer
      clear(reviewer)
      seed(community, reviewer)
    end
    community
  end

  private

  def set_up_community
    community = Community.find_or_initialize_by(slug: @slug)
    community.assign_attributes(name: @name, domain: @domain, status: "active",
      chat_enabled: true, collaborative_docs_enabled: true)
    community.save!
    community
  end

  def set_up_reviewer
    reviewer = User.find_or_initialize_by(email: EMAIL)
    reviewer.assign_attributes(name: REVIEWER_NAME, password: @password, password_confirmation: @password)
    reviewer.email_verified_at ||= Time.current
    reviewer.save!
    reviewer
  end

  # Everything in the community except the reviewer and the sample neighbours
  def clear(reviewer)
    Meal.destroy_all
    MealSchedule.destroy_all
    TaskAssignment.delete_all
    RecurringTaskResponsible.delete_all
    Task.with_discarded.destroy_all
    RecurringTask.with_discarded.destroy_all
    WorkstreamOwner.delete_all
    Workstream.destroy_all
    Decision.destroy_all
    Document.destroy_all
    DocumentFolder.destroy_all
    Invitation.destroy_all
    EmailLog.delete_all

    keep = [ reviewer.email ] + TaskSampleData::HOUSEHOLDS.keys.map { |name| TaskSampleData.email_for(name) }
    User.where.not(email: keep).destroy_all
    Household.where.not(id: User.select(:household_id)).destroy_all
  end

  def seed(community, reviewer)
    TaskSampleData.new(community, viewer: reviewer).load!
    neighbours = User.where(email: TaskSampleData::HOUSEHOLDS.keys.map { |name| TaskSampleData.email_for(name) }).index_by(&:name)
    seed_meals(community, neighbours)
    seed_chat(community, reviewer, neighbours) if StreamChatClient.configured?
  end

  def seed_meals(community, neighbours)
    today = Time.current.in_time_zone(community.time_zone).to_date
    guests = neighbours.values.first(4)
    MEALS.each_with_index do |(menu, cook), i|
      scheduled_at = (today + (i + 1).weeks).in_time_zone(community.time_zone).change(hour: 18)
      meal = Meal.create!(title: "Community Dinner", menu: menu, scheduled_at: scheduled_at,
        rsvp_deadline: scheduled_at - 1.day, status: "upcoming")
      meal.meal_cooks.create!(user: neighbours.fetch(cook), role: "head_cook")
      (guests - [ neighbours.fetch(cook) ]).each { |guest| meal.meal_rsvps.create!(user: guest, status: "attending") }
    end
  end

  # A few messages in General, after clearing last week's
  def seed_chat(community, reviewer, neighbours)
    client = StreamChatClient.client
    people = [ reviewer ] + neighbours.values
    client.upsert_users(people.map(&:stream_user_data))

    channel = client.channel("team",
      channel_id: StreamChannelService.community_channel_id(community, "general"),
      data: StreamChannelService.channel_data(community, name: "General Discussion", created_by_id: reviewer.stream_user_data[:id]))
    channel.query(user_id: reviewer.stream_user_data[:id])
    channel.add_members(people.map { |person| person.stream_user_data[:id] })
    channel.truncate
    CHAT.each { |name, text| channel.send_message({ text: text }, neighbours.fetch(name).stream_user_data[:id]) }
  end
end
