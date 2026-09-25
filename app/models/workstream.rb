# The organizing container for all community work. Every task rolls up to one.
class Workstream < ApplicationRecord
  acts_as_tenant :community

  TYPES = { "permanent" => "Ongoing Operations", "ad_hoc" => "One-Time Project" }.freeze
  PRIORITIES = %w[essential important nice_to_have].freeze
  PRIORITY_LABELS = { "essential" => "Essential", "important" => "Important", "nice_to_have" => "Nice to have" }.freeze

  belongs_to :owner, class_name: "User", optional: true
  has_many :tasks, dependent: :restrict_with_error
  has_many :recurring_tasks, dependent: :restrict_with_error

  validates :name, presence: true
  validates :workstream_type, inclusion: { in: TYPES.keys }
  validates :status, inclusion: { in: %w[active closed] }
  validates :priority, inclusion: { in: PRIORITIES }

  scope :open, -> { where(status: "active") }
  scope :ongoing, -> { where(workstream_type: "permanent") }
  scope :projects, -> { where(workstream_type: "ad_hoc") }
  scope :by_priority, -> { in_order_of(:priority, PRIORITIES).order(:name) }

  def self.priority_rank(priority)
    PRIORITIES.index(priority) || PRIORITIES.length
  end

  def self.priority_label(priority)
    PRIORITY_LABELS[priority]
  end

  def type_label = TYPES[workstream_type]
  def priority_label = self.class.priority_label(priority)
  def ongoing? = workstream_type == "permanent"
  def project? = workstream_type == "ad_hoc"
  def closed? = status == "closed"
  def essential? = priority == "essential"

  # A workstream is covered when someone owns it.
  def covered? = owner_id.present?

  def owned_by?(user) = user.present? && owner_id == user.id

  def close!
    update!(status: "closed")
  end

  def reopen!
    update!(status: "active")
  end
end
