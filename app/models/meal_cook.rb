class MealCook < ApplicationRecord
  has_paper_trail

  belongs_to :meal
  belongs_to :user

  validates :role, presence: true, inclusion: { in: %w[head_cook helper] }
  validates :user_id, uniqueness: { scope: :meal_id, message: "is already signed up to cook" }
  validates :guests_count, numericality: { greater_than_or_equal_to: 0 }
  validate :meal_accepts_cooks, on: :create
  validate :only_one_head_cook

  scope :head_cooks, -> { where(role: "head_cook") }
  scope :helpers, -> { where(role: "helper") }
  scope :recent, -> { order(created_at: :desc) }

  after_create :remove_user_rsvp

  ROLES = {
    head_cook: "head_cook",
    helper: "helper"
  }.freeze

  def head_cook?
    role == "head_cook"
  end

  def helper?
    role == "helper"
  end

  def role_display
    head_cook? ? "Head Cook" : "Helper"
  end

  def total_count
    1 + guests_count
  end

  def guests_display
    return nil if guests_count.zero?
    guests_count == 1 ? "+1 guest" : "+#{guests_count} guests"
  end

  private

  def meal_accepts_cooks
    return if meal.nil?
    unless meal.cook_slots_available?
      errors.add(:base, "This meal has all cook positions filled")
    end
  end

  def only_one_head_cook
    return unless role == "head_cook" && meal.present?
    existing_head_cook = meal.meal_cooks.head_cooks.where.not(id: id)
    if existing_head_cook.exists?
      errors.add(:role, "already has a head cook assigned")
    end
  end

  def remove_user_rsvp
    # Cooks don't need to RSVP separately - they're automatically attending
    meal.meal_rsvps.where(user: user).destroy_all
  end
end
