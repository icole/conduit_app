class CalendarShare < ApplicationRecord
  belongs_to :user

  validates :calendar_id, presence: true
  validates :user_id, uniqueness: { scope: :calendar_id, message: "already has access to this calendar" }

  scope :for_calendar_and_user, ->(calendar_id, user_id) { where(calendar_id: calendar_id, user_id: user_id) }

  def self.calendar_shared_with_user?(calendar_id, user)
    exists?(calendar_id: calendar_id, user_id: user.id)
  end
end
