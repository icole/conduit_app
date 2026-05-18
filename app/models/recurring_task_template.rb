class RecurringTaskTemplate < ApplicationRecord
  belongs_to :role

  FREQUENCIES = %w[daily weekly biweekly monthly quarterly].freeze

  validates :title, presence: true
  validates :frequency, presence: true, inclusion: { in: FREQUENCIES }

  def generate_task!(assigned_user)
    task = Task.create!(
      title: title,
      description: description,
      role: role,
      user: assigned_user,
      assigned_to_user: auto_assign_to_holder ? assigned_user : nil,
      status: auto_assign_to_holder ? "active" : "backlog"
    )
    update!(last_generated_at: Date.current)
    task
  end

  def due_for_generation?
    return true if last_generated_at.nil?

    case frequency
    when "daily"
      last_generated_at < Date.current
    when "weekly"
      last_generated_at < 1.week.ago.to_date
    when "biweekly"
      last_generated_at < 2.weeks.ago.to_date
    when "monthly"
      last_generated_at < 1.month.ago.to_date
    when "quarterly"
      last_generated_at < 3.months.ago.to_date
    end
  end
end
