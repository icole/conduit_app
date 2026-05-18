class Role < ApplicationRecord
  include Discardable
  has_paper_trail

  acts_as_tenant :community

  GROUPS = %w[hoa_officers garden facilities community].freeze
  ROLE_TYPES = %w[role committee].freeze

  has_many :role_assignments, dependent: :destroy
  has_many :users, through: :role_assignments
  # TODO: Uncomment as models are created in subsequent tasks
  # has_many :tasks, dependent: :nullify
  has_many :time_entries, dependent: :destroy
  # has_many :recurring_task_templates, dependent: :destroy

  validates :title, presence: true, uniqueness: { scope: :community_id }
  validates :role_type, presence: true, inclusion: { in: ROLE_TYPES }
  validates :group, inclusion: { in: GROUPS }, allow_blank: true

  scope :roles, -> { where(role_type: "role") }
  scope :committees, -> { where(role_type: "committee") }
  scope :in_group, ->(group) { where(group: group) }
  scope :vacant_roles, -> { where(vacant: true) }
  scope :filled, -> { where(vacant: false) }
  scope :ordered, -> { order(:group, :title) }

  default_scope { ordered }

  def current_holders
    role_assignments.active_assignments.holders
  end

  def current_backup
    role_assignments.active_assignments.backups.first
  end

  def update_vacancy!
    update_column(:vacant, role_assignments.active_assignments.holders.none?)
  end
end
