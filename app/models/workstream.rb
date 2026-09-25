# The organizing container for all community work. Every task rolls up to one.
class Workstream < ApplicationRecord
  acts_as_tenant :community

  TYPES = { "permanent" => "Ongoing Operations", "ad_hoc" => "One-Time Project" }.freeze
  PRIORITIES = %w[essential important nice_to_have].freeze
  PRIORITY_LABELS = { "essential" => "Essential", "important" => "Important", "nice_to_have" => "Nice to have" }.freeze

  has_many :workstream_owners, dependent: :destroy
  has_many :owners, -> { order(:name) }, through: :workstream_owners, source: :user
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

  # The first paragraph of the description, for cards.
  def summary = description.to_s.split(/\n\s*\n/).first.to_s.strip

  def type_label = TYPES[workstream_type]
  def priority_label = self.class.priority_label(priority)
  def ongoing? = workstream_type == "permanent"
  def project? = workstream_type == "ad_hoc"
  def closed? = status == "closed"
  def essential? = priority == "essential"

  scope :unowned, -> { where.missing(:workstream_owners) }

  # A workstream is covered when someone owns it.
  def covered? = owners.any?

  def owned_by?(user) = user.present? && owners.include?(user)

  # "Jane Smith", "Jane Smith & Mike Davis", "Ann, Bo & Cy"
  def owner_names
    owners.map(&:name).to_sentence(words_connector: ", ", two_words_connector: " & ", last_word_connector: " & ")
  end

  def close!
    update!(status: "closed")
  end

  def reopen!
    update!(status: "active")
  end
end
