# Roles & Time Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add community role management and time tracking within the existing Tasks tab, providing visibility into who holds what role, linking tasks to roles, and tracking time commitments.

**Architecture:** New `Role`, `RoleAssignment`, `TimeEntry`, and `RecurringTaskTemplate` models with PaperTrail auditing. Roles controller nested under the Tasks tab UI. Time entries logged per-task or as monthly reconciliation against a role. Recurring templates auto-generate tasks assigned to current role holders.

**Tech Stack:** Rails 8.0, Minitest, DaisyUI, Turbo/Stimulus, PaperTrail, Discard gem

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `app/models/role.rb` | Role model — title, duties, description, group, term, type |
| `app/models/role_assignment.rb` | Join: user ↔ role with assignment_type and term dates |
| `app/models/time_entry.rb` | Hours logged against task or role |
| `app/models/recurring_task_template.rb` | Template for auto-generated tasks per role |
| `app/controllers/roles_controller.rb` | CRUD for roles + directory view |
| `app/controllers/role_assignments_controller.rb` | Assign/unassign users to roles |
| `app/controllers/time_entries_controller.rb` | Log and view time entries |
| `app/controllers/recurring_task_templates_controller.rb` | CRUD for recurring templates |
| `app/views/roles/index.html.erb` | Roles directory grouped by category |
| `app/views/roles/show.html.erb` | Role detail: holder, duties, tasks, time |
| `app/views/roles/_role_card.html.erb` | Card partial for directory listing |
| `app/views/roles/_form.html.erb` | Create/edit role form |
| `app/views/role_assignments/_form.html.erb` | Assign user to role form |
| `app/views/time_entries/_form.html.erb` | Log time form (modal) |
| `app/views/time_entries/_summary.html.erb` | Time summary partial for role detail |
| `app/views/tasks/_role_select.html.erb` | Role dropdown partial for task form |
| `test/models/role_test.rb` | Role model tests |
| `test/models/role_assignment_test.rb` | RoleAssignment model tests |
| `test/models/time_entry_test.rb` | TimeEntry model tests |
| `test/models/recurring_task_template_test.rb` | RecurringTaskTemplate model tests |
| `test/controllers/roles_controller_test.rb` | Roles controller tests |
| `test/controllers/time_entries_controller_test.rb` | Time entries controller tests |
| `test/system/roles_test.rb` | System tests for roles UI |
| `test/fixtures/roles.yml` | Role fixtures |
| `test/fixtures/role_assignments.yml` | RoleAssignment fixtures |
| `test/fixtures/time_entries.yml` | TimeEntry fixtures |
| `db/migrate/TIMESTAMP_create_roles.rb` | Roles table migration |
| `db/migrate/TIMESTAMP_create_role_assignments.rb` | RoleAssignments table migration |
| `db/migrate/TIMESTAMP_create_time_entries.rb` | TimeEntries table migration |
| `db/migrate/TIMESTAMP_add_role_id_to_tasks.rb` | Add optional role FK to tasks |
| `db/migrate/TIMESTAMP_create_recurring_task_templates.rb` | RecurringTaskTemplates table |

### Modified Files

| File | Change |
|------|--------|
| `config/routes.rb` | Add role, role_assignment, time_entry routes |
| `app/models/task.rb` | Add `belongs_to :role, optional: true` |
| `app/models/user.rb` | Add `has_many :role_assignments` and `has_many :roles` |
| `app/views/tasks/index.html.erb` | Add roles entry point icon in header |
| `app/views/tasks/_form.html.erb` | Add optional role select field |
| `app/controllers/tasks_controller.rb` | Permit `:role_id` in strong params |
| `test/fixtures/tasks.yml` | Add role references to some fixtures |

---

## Task 1: Create Role Model and Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_create_roles.rb`
- Create: `app/models/role.rb`
- Create: `test/models/role_test.rb`
- Create: `test/fixtures/roles.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/role_test.rb`:

```ruby
require "test_helper"

class RoleTest < ActiveSupport::TestCase
  def setup
    @community = communities(:crow_woods)
  end

  test "should require title" do
    role = Role.new(title: nil, role_type: "role")
    assert_not role.valid?
    assert_includes role.errors[:title], "can't be blank"
  end

  test "should require role_type" do
    role = Role.new(title: "Test Role", role_type: nil)
    assert_not role.valid?
    assert_includes role.errors[:role_type], "can't be blank"
  end

  test "should validate role_type inclusion" do
    role = Role.new(title: "Test Role", role_type: "invalid")
    assert_not role.valid?
    assert_includes role.errors[:role_type], "is not included in the list"
  end

  test "should validate group inclusion" do
    role = Role.new(title: "Test Role", role_type: "role", group: "invalid")
    assert_not role.valid?
    assert_includes role.errors[:group], "is not included in the list"
  end

  test "should allow valid role" do
    role = Role.new(
      title: "Garden Health Maven",
      role_type: "role",
      group: "garden",
      term_length_months: 6,
      duties: "Maintain landscaping health"
    )
    assert role.valid?
  end

  test "should default vacant to true" do
    role = Role.new(title: "Test", role_type: "role")
    assert role.vacant?
  end

  test "should scope by role_type" do
    assert Role.roles.all? { |r| r.role_type == "role" }
    assert Role.committees.all? { |r| r.role_type == "committee" }
  end

  test "should scope by group" do
    assert Role.in_group("hoa_officers").all? { |r| r.group == "hoa_officers" }
  end

  test "should have paper_trail" do
    role = roles(:garden_maven)
    assert role.respond_to?(:versions)
  end
end
```

- [ ] **Step 2: Create fixtures**

Create `test/fixtures/roles.yml`:

```yaml
garden_maven:
  community: crow_woods
  title: Garden Health Maven
  role_type: role
  group: garden
  term_length_months: 6
  duties: "Manage watering, plant health, equipment maintenance, winterizing"
  description: "Use the Common House spigot when possible. Hoses stored in common storage room."
  vacant: false

president:
  community: crow_woods
  title: HOA President
  role_type: role
  group: hoa_officers
  term_length_months: 12
  duties: "Draft agendas, oversee community guidelines review, run HOA meetings, handle crises"
  vacant: false

facilitator:
  community: crow_woods
  title: Facilitator
  role_type: role
  group: community
  term_length_months: 6
  duties: "Co-facilitate monthly meetings, create agenda, send agenda, follow up on action items"
  vacant: true

signage_committee:
  community: crow_woods
  title: Signage Committee
  role_type: committee
  group: community
  term_length_months: 3
  duties: "Design, source, and install community signage"
  vacant: false
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/models/role_test.rb`
Expected: Error — `Role` class not found / table doesn't exist

- [ ] **Step 4: Create the migration**

Run: `bin/rails generate migration CreateRoles`

Edit the generated migration:

```ruby
class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles do |t|
      t.references :community, null: false, foreign_key: true
      t.string :title, null: false
      t.text :duties
      t.text :description
      t.string :group
      t.string :role_type, null: false, default: "role"
      t.integer :term_length_months
      t.boolean :vacant, default: true, null: false
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :roles, :group
    add_index :roles, :role_type
    add_index :roles, :vacant
    add_index :roles, :discarded_at
    add_index :roles, [ :community_id, :title ], unique: true
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create the model**

Create `app/models/role.rb`:

```ruby
class Role < ApplicationRecord
  include Discardable
  has_paper_trail

  acts_as_tenant :community

  GROUPS = %w[hoa_officers garden facilities community].freeze
  ROLE_TYPES = %w[role committee].freeze

  has_many :role_assignments, dependent: :destroy
  has_many :users, through: :role_assignments
  has_many :tasks, dependent: :nullify
  has_many :time_entries, dependent: :destroy
  has_many :recurring_task_templates, dependent: :destroy

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
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/models/role_test.rb`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_roles.rb app/models/role.rb test/models/role_test.rb test/fixtures/roles.yml
git commit -m "Add Role model with validations, scopes, and PaperTrail"
```

---

## Task 2: Create RoleAssignment Model and Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_create_role_assignments.rb`
- Create: `app/models/role_assignment.rb`
- Create: `test/models/role_assignment_test.rb`
- Create: `test/fixtures/role_assignments.yml`
- Modify: `app/models/user.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/role_assignment_test.rb`:

```ruby
require "test_helper"

class RoleAssignmentTest < ActiveSupport::TestCase
  def setup
    @role = roles(:garden_maven)
    @user = users(:one)
  end

  test "should require role" do
    assignment = RoleAssignment.new(user: @user, assignment_type: "holder", starts_at: Date.current)
    assert_not assignment.valid?
    assert_includes assignment.errors[:role], "must exist"
  end

  test "should require user" do
    assignment = RoleAssignment.new(role: @role, assignment_type: "holder", starts_at: Date.current)
    assert_not assignment.valid?
    assert_includes assignment.errors[:user], "must exist"
  end

  test "should require assignment_type" do
    assignment = RoleAssignment.new(role: @role, user: @user, assignment_type: nil, starts_at: Date.current)
    assert_not assignment.valid?
    assert_includes assignment.errors[:assignment_type], "can't be blank"
  end

  test "should validate assignment_type inclusion" do
    assignment = RoleAssignment.new(role: @role, user: @user, assignment_type: "invalid", starts_at: Date.current)
    assert_not assignment.valid?
    assert_includes assignment.errors[:assignment_type], "is not included in the list"
  end

  test "should require starts_at" do
    assignment = RoleAssignment.new(role: @role, user: @user, assignment_type: "holder", starts_at: nil)
    assert_not assignment.valid?
    assert_includes assignment.errors[:starts_at], "can't be blank"
  end

  test "should allow valid assignment" do
    assignment = RoleAssignment.new(
      role: @role,
      user: @user,
      assignment_type: "holder",
      starts_at: Date.current,
      ends_at: 6.months.from_now.to_date,
      active: true
    )
    assert assignment.valid?
  end

  test "should scope active assignments" do
    active = role_assignments(:maven_holder)
    assert_includes RoleAssignment.active_assignments, active
  end

  test "should scope by assignment type" do
    holder = role_assignments(:maven_holder)
    backup = role_assignments(:maven_backup)
    assert_includes RoleAssignment.holders, holder
    assert_includes RoleAssignment.backups, backup
  end

  test "should detect expiring soon" do
    assignment = role_assignments(:maven_holder)
    assignment.update!(ends_at: 20.days.from_now.to_date)
    assert_includes RoleAssignment.expiring_soon, assignment
  end

  test "should update role vacancy on create" do
    role = roles(:facilitator)
    assert role.vacant?

    RoleAssignment.create!(
      role: role,
      user: @user,
      assignment_type: "holder",
      starts_at: Date.current,
      active: true
    )

    role.reload
    assert_not role.vacant?
  end

  test "should have paper_trail" do
    assignment = role_assignments(:maven_holder)
    assert assignment.respond_to?(:versions)
  end
end
```

- [ ] **Step 2: Create fixtures**

Create `test/fixtures/role_assignments.yml`:

```yaml
maven_holder:
  role: garden_maven
  user: one
  assignment_type: holder
  starts_at: <%= 2.months.ago.to_date %>
  ends_at: <%= 4.months.from_now.to_date %>
  active: true

maven_backup:
  role: garden_maven
  user: two
  assignment_type: backup
  starts_at: <%= 2.months.ago.to_date %>
  ends_at: <%= 4.months.from_now.to_date %>
  active: true

president_holder:
  role: president
  user: two
  assignment_type: holder
  starts_at: <%= 6.months.ago.to_date %>
  ends_at: <%= 6.months.from_now.to_date %>
  active: true

signage_member_one:
  role: signage_committee
  user: one
  assignment_type: holder
  starts_at: <%= 1.month.ago.to_date %>
  ends_at: <%= 2.months.from_now.to_date %>
  active: true
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/models/role_assignment_test.rb`
Expected: Error — `RoleAssignment` class not found

- [ ] **Step 4: Create the migration**

Run: `bin/rails generate migration CreateRoleAssignments`

Edit the generated migration:

```ruby
class CreateRoleAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :role_assignments do |t|
      t.references :role, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :assignment_type, null: false, default: "holder"
      t.date :starts_at, null: false
      t.date :ends_at
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :role_assignments, :assignment_type
    add_index :role_assignments, :active
    add_index :role_assignments, :ends_at
    add_index :role_assignments, [ :role_id, :user_id, :active ], name: "idx_role_assignments_unique_active",
              unique: true, where: "active = true AND assignment_type = 'holder'"
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create the model**

Create `app/models/role_assignment.rb`:

```ruby
class RoleAssignment < ApplicationRecord
  has_paper_trail

  belongs_to :role
  belongs_to :user

  ASSIGNMENT_TYPES = %w[holder backup co_holder].freeze

  validates :assignment_type, presence: true, inclusion: { in: ASSIGNMENT_TYPES }
  validates :starts_at, presence: true

  after_save :update_role_vacancy
  after_destroy :update_role_vacancy

  scope :active_assignments, -> { where(active: true) }
  scope :holders, -> { where(assignment_type: "holder") }
  scope :backups, -> { where(assignment_type: "backup") }
  scope :co_holders, -> { where(assignment_type: "co_holder") }
  scope :expiring_soon, -> { where(active: true).where("ends_at <= ?", 30.days.from_now.to_date) }

  def expired?
    ends_at.present? && ends_at < Date.current
  end

  def expiring_soon?
    ends_at.present? && ends_at <= 30.days.from_now.to_date && ends_at >= Date.current
  end

  private

  def update_role_vacancy
    role.update_vacancy!
  end
end
```

- [ ] **Step 6: Add associations to User model**

In `app/models/user.rb`, add:

```ruby
has_many :role_assignments, dependent: :destroy
has_many :roles, through: :role_assignments
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/models/role_assignment_test.rb`
Expected: All tests pass

- [ ] **Step 8: Commit**

```bash
git add db/migrate/*_create_role_assignments.rb app/models/role_assignment.rb test/models/role_assignment_test.rb test/fixtures/role_assignments.yml app/models/user.rb
git commit -m "Add RoleAssignment model with term tracking and vacancy management"
```

---

## Task 3: Create TimeEntry Model and Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_create_time_entries.rb`
- Create: `app/models/time_entry.rb`
- Create: `test/models/time_entry_test.rb`
- Create: `test/fixtures/time_entries.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/time_entry_test.rb`:

```ruby
require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @role = roles(:garden_maven)
    @task = tasks(:one)
  end

  test "should require user" do
    entry = TimeEntry.new(hours: 2.0, logged_on: Date.current, entry_type: "task")
    assert_not entry.valid?
    assert_includes entry.errors[:user], "must exist"
  end

  test "should require hours" do
    entry = TimeEntry.new(user: @user, logged_on: Date.current, entry_type: "reconciliation", role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:hours], "can't be blank"
  end

  test "should require positive hours" do
    entry = TimeEntry.new(user: @user, hours: -1, logged_on: Date.current, entry_type: "reconciliation", role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:hours], "must be greater than 0"
  end

  test "should require logged_on" do
    entry = TimeEntry.new(user: @user, hours: 2.0, entry_type: "reconciliation", role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:logged_on], "can't be blank"
  end

  test "should require entry_type" do
    entry = TimeEntry.new(user: @user, hours: 2.0, logged_on: Date.current, role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:entry_type], "can't be blank"
  end

  test "should validate entry_type inclusion" do
    entry = TimeEntry.new(user: @user, hours: 2.0, logged_on: Date.current, entry_type: "invalid", role: @role)
    assert_not entry.valid?
    assert_includes entry.errors[:entry_type], "is not included in the list"
  end

  test "should allow valid task time entry" do
    entry = TimeEntry.new(
      user: @user,
      task: @task,
      role: @role,
      hours: 1.5,
      logged_on: Date.current,
      entry_type: "task"
    )
    assert entry.valid?
  end

  test "should allow valid reconciliation entry" do
    entry = TimeEntry.new(
      user: @user,
      role: @role,
      hours: 3.0,
      logged_on: Date.current,
      entry_type: "reconciliation",
      note: "Side conversations and informal maintenance"
    )
    assert entry.valid?
  end

  test "should scope by entry_type" do
    assert TimeEntry.task_entries.all? { |e| e.entry_type == "task" }
    assert TimeEntry.reconciliation_entries.all? { |e| e.entry_type == "reconciliation" }
  end

  test "should scope by month" do
    entry = time_entries(:maven_task_entry)
    results = TimeEntry.for_month(entry.logged_on.year, entry.logged_on.month)
    assert_includes results, entry
  end

  test "should calculate total hours for a role" do
    total = TimeEntry.where(role: @role).sum(:hours)
    assert total > 0
  end
end
```

- [ ] **Step 2: Create fixtures**

Create `test/fixtures/time_entries.yml`:

```yaml
maven_task_entry:
  user: one
  task: one
  role: garden_maven
  hours: 1.5
  logged_on: <%= Date.current %>
  entry_type: task
  note: ""

maven_reconciliation:
  user: one
  role: garden_maven
  hours: 3.0
  logged_on: <%= Date.current.beginning_of_month %>
  entry_type: reconciliation
  note: "Informal grounds checks and neighbor conversations"

president_entry:
  user: two
  role: president
  hours: 4.0
  logged_on: <%= 1.week.ago.to_date %>
  entry_type: reconciliation
  note: "Agenda prep and crisis management calls"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/models/time_entry_test.rb`
Expected: Error — `TimeEntry` class not found

- [ ] **Step 4: Create the migration**

Run: `bin/rails generate migration CreateTimeEntries`

Edit the generated migration:

```ruby
class CreateTimeEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :time_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, foreign_key: true
      t.references :role, foreign_key: true
      t.decimal :hours, precision: 5, scale: 2, null: false
      t.date :logged_on, null: false
      t.string :entry_type, null: false
      t.string :note
      t.timestamps
    end

    add_index :time_entries, :entry_type
    add_index :time_entries, :logged_on
    add_index :time_entries, [ :user_id, :logged_on ]
    add_index :time_entries, [ :role_id, :logged_on ]
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create the model**

Create `app/models/time_entry.rb`:

```ruby
class TimeEntry < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true
  belongs_to :role, optional: true

  ENTRY_TYPES = %w[task reconciliation].freeze

  validates :hours, presence: true, numericality: { greater_than: 0 }
  validates :logged_on, presence: true
  validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }

  scope :task_entries, -> { where(entry_type: "task") }
  scope :reconciliation_entries, -> { where(entry_type: "reconciliation") }
  scope :for_month, ->(year, month) {
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    where(logged_on: start_date..end_date)
  }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_role, ->(role) { where(role: role) }
  scope :recent, -> { order(logged_on: :desc) }
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/models/time_entry_test.rb`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_time_entries.rb app/models/time_entry.rb test/models/time_entry_test.rb test/fixtures/time_entries.yml
git commit -m "Add TimeEntry model for per-task and reconciliation time tracking"
```

---

## Task 4: Create RecurringTaskTemplate Model and Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_create_recurring_task_templates.rb`
- Create: `app/models/recurring_task_template.rb`
- Create: `test/models/recurring_task_template_test.rb`
- Create: `test/fixtures/recurring_task_templates.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/recurring_task_template_test.rb`:

```ruby
require "test_helper"

class RecurringTaskTemplateTest < ActiveSupport::TestCase
  def setup
    @role = roles(:garden_maven)
  end

  test "should require role" do
    template = RecurringTaskTemplate.new(title: "Test", frequency: "weekly")
    assert_not template.valid?
    assert_includes template.errors[:role], "must exist"
  end

  test "should require title" do
    template = RecurringTaskTemplate.new(role: @role, frequency: "weekly")
    assert_not template.valid?
    assert_includes template.errors[:title], "can't be blank"
  end

  test "should require frequency" do
    template = RecurringTaskTemplate.new(role: @role, title: "Test")
    assert_not template.valid?
    assert_includes template.errors[:frequency], "can't be blank"
  end

  test "should validate frequency inclusion" do
    template = RecurringTaskTemplate.new(role: @role, title: "Test", frequency: "hourly")
    assert_not template.valid?
    assert_includes template.errors[:frequency], "is not included in the list"
  end

  test "should allow valid template" do
    template = RecurringTaskTemplate.new(
      role: @role,
      title: "Grounds walk",
      description: "Walk the grounds to observe and respond to landscaping needs",
      frequency: "biweekly",
      auto_assign_to_holder: true
    )
    assert template.valid?
  end

  test "should generate a task" do
    template = recurring_task_templates(:grounds_walk)
    user = users(:one)

    task = template.generate_task!(user)

    assert task.persisted?
    assert_equal template.title, task.title
    assert_equal template.description, task.description
    assert_equal template.role, task.role
    assert_equal user, task.assigned_to_user
  end
end
```

- [ ] **Step 2: Create fixtures**

Create `test/fixtures/recurring_task_templates.yml`:

```yaml
grounds_walk:
  role: garden_maven
  title: Grounds walk
  description: "Walk the grounds to observe and respond to landscaping needs"
  frequency: biweekly
  auto_assign_to_holder: true

garbage_day:
  role: garden_maven
  title: Take out garbage bins
  description: "Take out all garbage, recycling, and yard waste bins on garbage day"
  frequency: weekly
  auto_assign_to_holder: true

hot_tub_maintenance:
  role: signage_committee
  title: Hot tub filter check
  description: "Check and clean hot tub filter cartridge"
  frequency: monthly
  auto_assign_to_holder: true
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/models/recurring_task_template_test.rb`
Expected: Error — `RecurringTaskTemplate` class not found

- [ ] **Step 4: Create the migration**

Run: `bin/rails generate migration CreateRecurringTaskTemplates`

Edit the generated migration:

```ruby
class CreateRecurringTaskTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_task_templates do |t|
      t.references :role, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :frequency, null: false
      t.boolean :auto_assign_to_holder, default: true, null: false
      t.date :last_generated_at
      t.timestamps
    end

    add_index :recurring_task_templates, :frequency
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create the model**

Create `app/models/recurring_task_template.rb`:

```ruby
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
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/models/recurring_task_template_test.rb`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_recurring_task_templates.rb app/models/recurring_task_template.rb test/models/recurring_task_template_test.rb test/fixtures/recurring_task_templates.yml
git commit -m "Add RecurringTaskTemplate model for auto-generating role tasks"
```

---

## Task 5: Link Tasks to Roles

**Files:**
- Create: `db/migrate/TIMESTAMP_add_role_id_to_tasks.rb`
- Modify: `app/models/task.rb`
- Modify: `app/controllers/tasks_controller.rb`
- Modify: `test/fixtures/tasks.yml`
- Modify: `test/models/task_test.rb`

- [ ] **Step 1: Write the failing test**

Add to `test/models/task_test.rb`:

```ruby
test "should optionally belong to a role" do
  role = roles(:garden_maven)
  task = Task.create!(title: "Winterize spigots", user: @user, role: role)
  assert_equal role, task.role
end

test "should not require role" do
  task = Task.new(title: "Unrelated task", user: @user)
  assert task.valid?
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/task_test.rb`
Expected: Error — unknown attribute `role` for Task

- [ ] **Step 3: Create the migration**

Run: `bin/rails generate migration AddRoleIdToTasks`

Edit the generated migration:

```ruby
class AddRoleIdToTasks < ActiveRecord::Migration[8.0]
  def change
    add_reference :tasks, :role, foreign_key: true
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 4: Update Task model**

In `app/models/task.rb`, add the association after `belongs_to :assigned_to_user`:

```ruby
belongs_to :role, optional: true
```

- [ ] **Step 5: Update strong params in TasksController**

In `app/controllers/tasks_controller.rb`, update `task_params`:

```ruby
def task_params
  params.require(:task).permit(:title, :description, :status, :assigned_to_user_id, :due_date, :role_id)
end
```

- [ ] **Step 6: Update task fixtures**

In `test/fixtures/tasks.yml`, add a role reference to one fixture:

```yaml
assigned_task:
  community: crow_woods
  title: "Review Pull Request #42"
  status: active
  priority_order: 1
  user: one
  assigned_to_user: two
  role: garden_maven
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/models/task_test.rb`
Expected: All tests pass

- [ ] **Step 8: Commit**

```bash
git add db/migrate/*_add_role_id_to_tasks.rb app/models/task.rb app/controllers/tasks_controller.rb test/models/task_test.rb test/fixtures/tasks.yml
git commit -m "Add optional role association to tasks"
```

---

## Task 6: Roles Controller and Routes

**Files:**
- Create: `app/controllers/roles_controller.rb`
- Create: `test/controllers/roles_controller_test.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/roles_controller_test.rb`:

```ruby
require "test_helper"

class RolesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(@user)
    @role = roles(:garden_maven)
  end

  test "should get index" do
    get roles_url
    assert_response :success
    assert_select "h1", /Roles/
  end

  test "should get show" do
    get role_url(@role)
    assert_response :success
    assert_select "h1", @role.title
  end

  test "should get new" do
    get new_role_url
    assert_response :success
  end

  test "should create role" do
    assert_difference("Role.count") do
      post roles_url, params: { role: {
        title: "New Test Role",
        role_type: "role",
        group: "community",
        duties: "Do the thing",
        term_length_months: 6
      } }
    end
    assert_redirected_to role_url(Role.last)
  end

  test "should get edit" do
    get edit_role_url(@role)
    assert_response :success
  end

  test "should update role" do
    patch role_url(@role), params: { role: { title: "Updated Title" } }
    assert_redirected_to role_url(@role)
    @role.reload
    assert_equal "Updated Title", @role.title
  end

  test "should soft delete role" do
    assert_difference("Role.count", -1) do
      delete role_url(@role)
    end
    assert_redirected_to roles_url
    assert Role.with_discarded.find(@role.id).discarded?
  end

  test "should require authentication" do
    sign_out
    get roles_url
    assert_redirected_to new_session_path
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/roles_controller_test.rb`
Expected: Error — `roles_url` not defined (no route)

- [ ] **Step 3: Add routes**

In `config/routes.rb`, add after the `resources :tasks` block:

```ruby
resources :roles do
  resources :role_assignments, only: [ :new, :create, :destroy ], shallow: true
  resources :time_entries, only: [ :new, :create ], shallow: true
  resources :recurring_task_templates, only: [ :new, :create, :edit, :update, :destroy ], shallow: true
end

resources :time_entries, only: [ :index, :destroy ]
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/roles_controller.rb`:

```ruby
class RolesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_role, only: [ :show, :edit, :update, :destroy ]

  def index
    @roles_by_group = Role.includes(:role_assignments, :users).group_by(&:group)
  end

  def show
    @assignments = @role.role_assignments.active_assignments.includes(:user)
    @tasks = @role.tasks.limit(20)
    @time_entries = @role.time_entries.recent.limit(10)
    @templates = @role.recurring_task_templates
  end

  def new
    @role = Role.new
  end

  def create
    @role = Role.new(role_params)

    if @role.save
      redirect_to role_url(@role), notice: "Role was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @role.update(role_params)
      redirect_to role_url(@role), notice: "Role was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @role.discard
    redirect_to roles_url, notice: "Role was deleted."
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:title, :duties, :description, :group, :role_type, :term_length_months)
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/roles_controller_test.rb`
Expected: All tests pass (may need view templates — create minimal ones first)

- [ ] **Step 6: Create minimal view templates**

Create `app/views/roles/index.html.erb`:

```erb
<div class="<%= hotwire_native_app? ? '' : '-mx-2 sm:mx-0 px-2 sm:px-0' %>">
  <div class="flex justify-between items-center gap-2 mb-4">
    <h1 class="text-xl sm:text-2xl font-bold">Roles</h1>
    <%= link_to "Add Role", new_role_path, class: "btn btn-primary btn-sm" %>
  </div>

  <% Role::GROUPS.each do |group| %>
    <% roles = @roles_by_group[group] %>
    <% if roles.present? %>
      <h2 class="text-lg font-semibold mt-6 mb-3 capitalize"><%= group.humanize.titleize %></h2>
      <div class="space-y-2">
        <% roles.each do |role| %>
          <%= render "roles/role_card", role: role %>
        <% end %>
      </div>
    <% end %>
  <% end %>

  <% committees = @roles_by_group[nil]&.select { |r| r.role_type == "committee" } %>
  <% if committees.present? %>
    <h2 class="text-lg font-semibold mt-6 mb-3">Committees</h2>
    <div class="space-y-2">
      <% committees.each do |role| %>
        <%= render "roles/role_card", role: role %>
      <% end %>
    </div>
  <% end %>

  <div class="mt-6">
    <%= link_to "Back to Tasks", tasks_path, class: "btn btn-ghost btn-sm" %>
  </div>
</div>
```

Create `app/views/roles/_role_card.html.erb`:

```erb
<%= link_to role_path(role), class: "card bg-base-100 border border-base-200 p-3 block hover:bg-base-200 transition" do %>
  <div class="flex items-center justify-between">
    <div>
      <h3 class="font-medium text-sm sm:text-base"><%= role.title %></h3>
      <% if role.current_holders.any? %>
        <p class="text-xs text-base-content/60 mt-0.5">
          <%= role.current_holders.map { |a| a.user.name }.join(", ") %>
        </p>
      <% end %>
    </div>
    <% if role.vacant? %>
      <span class="badge badge-warning badge-sm">Vacant</span>
    <% end %>
  </div>
<% end %>
```

Create `app/views/roles/show.html.erb`:

```erb
<div class="<%= hotwire_native_app? ? '' : '-mx-2 sm:mx-0 px-2 sm:px-0' %>">
  <div class="flex justify-between items-center gap-2 mb-4">
    <h1 class="text-xl sm:text-2xl font-bold"><%= @role.title %></h1>
    <%= link_to "Edit", edit_role_path(@role), class: "btn btn-ghost btn-sm" %>
  </div>

  <% if @role.vacant? %>
    <div class="alert alert-warning mb-4">
      <span>This role is currently vacant.</span>
    </div>
  <% end %>

  <!-- Current Holders -->
  <div class="mb-6">
    <h2 class="text-lg font-semibold mb-2">Assigned</h2>
    <% if @assignments.any? %>
      <% @assignments.each do |assignment| %>
        <div class="flex items-center justify-between py-2 border-b border-base-200">
          <div>
            <span class="font-medium"><%= assignment.user.name %></span>
            <span class="badge badge-ghost badge-sm ml-2"><%= assignment.assignment_type.humanize %></span>
          </div>
          <span class="text-xs text-base-content/60">
            Ends: <%= assignment.ends_at&.strftime("%b %Y") || "No end date" %>
          </span>
        </div>
      <% end %>
    <% else %>
      <p class="text-sm text-base-content/50">No one is currently assigned.</p>
    <% end %>
    <%= link_to "Assign Someone", new_role_role_assignment_path(@role), class: "btn btn-sm btn-outline mt-2" %>
  </div>

  <!-- Duties -->
  <% if @role.duties.present? %>
    <div class="mb-6">
      <h2 class="text-lg font-semibold mb-2">Duties</h2>
      <div class="prose prose-sm"><%= simple_format(@role.duties) %></div>
    </div>
  <% end %>

  <!-- Description / Guide -->
  <% if @role.description.present? %>
    <div class="mb-6">
      <h2 class="text-lg font-semibold mb-2">Role Guide</h2>
      <div class="prose prose-sm"><%= simple_format(@role.description) %></div>
    </div>
  <% end %>

  <!-- Time Summary -->
  <div class="mb-6">
    <h2 class="text-lg font-semibold mb-2">Time This Month</h2>
    <% monthly_hours = @role.time_entries.for_month(Date.current.year, Date.current.month).sum(:hours) %>
    <p class="text-2xl font-bold"><%= monthly_hours %> <span class="text-sm font-normal text-base-content/60">hours</span></p>
    <%= link_to "Log Time", new_role_time_entry_path(@role), class: "btn btn-sm btn-outline mt-2" %>
  </div>

  <!-- Linked Tasks -->
  <% if @tasks.any? %>
    <div class="mb-6">
      <h2 class="text-lg font-semibold mb-2">Tasks</h2>
      <div class="space-y-1">
        <% @tasks.each do |task| %>
          <%= render "tasks/task_card_mobile", task: task, show_prioritize: false, show_move_to_backlog: false %>
        <% end %>
      </div>
    </div>
  <% end %>

  <!-- Audit History -->
  <div class="collapse collapse-arrow bg-base-200 mb-6">
    <input type="checkbox" />
    <div class="collapse-title text-sm font-medium">Change History</div>
    <div class="collapse-content">
      <% @role.versions.reverse.first(20).each do |version| %>
        <div class="text-xs py-1 border-b border-base-300">
          <span class="font-medium"><%= version.whodunnit || "System" %></span>
          <span class="text-base-content/60"><%= version.event %> on <%= version.created_at.strftime("%b %d, %Y") %></span>
        </div>
      <% end %>
    </div>
  </div>

  <%= link_to "Back to Roles", roles_path, class: "btn btn-ghost btn-sm" %>
</div>
```

Create `app/views/roles/new.html.erb`:

```erb
<div class="<%= hotwire_native_app? ? '' : '-mx-2 sm:mx-0 px-2 sm:px-0' %>">
  <h1 class="text-xl sm:text-2xl font-bold mb-4">New Role</h1>
  <%= render "roles/form", role: @role %>
</div>
```

Create `app/views/roles/edit.html.erb`:

```erb
<div class="<%= hotwire_native_app? ? '' : '-mx-2 sm:mx-0 px-2 sm:px-0' %>">
  <h1 class="text-xl sm:text-2xl font-bold mb-4">Edit <%= @role.title %></h1>
  <%= render "roles/form", role: @role %>
</div>
```

Create `app/views/roles/_form.html.erb`:

```erb
<%= form_with(model: role) do |form| %>
  <% if role.errors.any? %>
    <div class="alert alert-error mb-4">
      <ul>
        <% role.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="form-control w-full mb-4">
    <%= form.label :title, class: "label" %>
    <%= form.text_field :title, class: "input input-bordered w-full", required: true %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :role_type, "Type", class: "label" %>
    <%= form.select :role_type, Role::ROLE_TYPES.map { |t| [t.humanize, t] }, {}, class: "select select-bordered w-full" %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :group, "Category", class: "label" %>
    <%= form.select :group, Role::GROUPS.map { |g| [g.humanize.titleize, g] }, { include_blank: "None" }, class: "select select-bordered w-full" %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :term_length_months, "Term Length (months)", class: "label" %>
    <%= form.number_field :term_length_months, class: "input input-bordered w-full", min: 1 %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :duties, "Duties (official responsibilities)", class: "label" %>
    <%= form.text_area :duties, class: "textarea textarea-bordered w-full", rows: 6 %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :description, "Role Guide (practical tips for the holder)", class: "label" %>
    <%= form.text_area :description, class: "textarea textarea-bordered w-full", rows: 4 %>
  </div>

  <div class="flex justify-end gap-2 mt-6">
    <%= link_to "Cancel", roles_path, class: "btn btn-ghost" %>
    <%= form.submit role.persisted? ? "Update" : "Create Role", class: "btn btn-primary" %>
  </div>
<% end %>
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/controllers/roles_controller_test.rb`
Expected: All tests pass

- [ ] **Step 8: Commit**

```bash
git add app/controllers/roles_controller.rb app/views/roles/ test/controllers/roles_controller_test.rb config/routes.rb
git commit -m "Add roles controller, routes, and views for directory and CRUD"
```

---

## Task 7: Role Assignments Controller

**Files:**
- Create: `app/controllers/role_assignments_controller.rb`
- Create: `app/views/role_assignments/_form.html.erb`
- Create: `app/views/role_assignments/new.html.erb`
- Create: `test/controllers/role_assignments_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/role_assignments_controller_test.rb`:

```ruby
require "test_helper"

class RoleAssignmentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(@user)
    @role = roles(:facilitator)
    @assignment = role_assignments(:maven_holder)
  end

  test "should get new" do
    get new_role_role_assignment_url(@role)
    assert_response :success
  end

  test "should create role assignment" do
    assert_difference("RoleAssignment.count") do
      post role_role_assignments_url(@role), params: { role_assignment: {
        user_id: @user.id,
        assignment_type: "holder",
        starts_at: Date.current,
        ends_at: 6.months.from_now.to_date
      } }
    end
    assert_redirected_to role_url(@role)
  end

  test "should destroy role assignment" do
    assert_difference("RoleAssignment.count", -1) do
      delete role_assignment_url(@assignment)
    end
    assert_redirected_to role_url(@assignment.role)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/role_assignments_controller_test.rb`
Expected: Error — controller not found

- [ ] **Step 3: Create the controller**

Create `app/controllers/role_assignments_controller.rb`:

```ruby
class RoleAssignmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_role, only: [ :new, :create ]
  before_action :set_assignment, only: [ :destroy ]

  def new
    @assignment = @role.role_assignments.new
    @users = User.all
  end

  def create
    @assignment = @role.role_assignments.new(assignment_params)

    if @assignment.save
      redirect_to role_url(@role), notice: "#{@assignment.user.name} assigned as #{@assignment.assignment_type.humanize}."
    else
      @users = User.all
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    role = @assignment.role
    @assignment.destroy
    redirect_to role_url(role), notice: "Assignment removed."
  end

  private

  def set_role
    @role = Role.find(params[:role_id])
  end

  def set_assignment
    @assignment = RoleAssignment.find(params[:id])
  end

  def assignment_params
    params.require(:role_assignment).permit(:user_id, :assignment_type, :starts_at, :ends_at)
  end
end
```

- [ ] **Step 4: Create views**

Create `app/views/role_assignments/new.html.erb`:

```erb
<div class="<%= hotwire_native_app? ? '' : '-mx-2 sm:mx-0 px-2 sm:px-0' %>">
  <h1 class="text-xl font-bold mb-4">Assign: <%= @role.title %></h1>
  <%= render "role_assignments/form", assignment: @assignment, role: @role %>
</div>
```

Create `app/views/role_assignments/_form.html.erb`:

```erb
<%= form_with(model: [ role, assignment ]) do |form| %>
  <% if assignment.errors.any? %>
    <div class="alert alert-error mb-4">
      <ul>
        <% assignment.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="form-control w-full mb-4">
    <%= form.label :user_id, "Person", class: "label" %>
    <%= form.select :user_id, @users.map { |u| [u.name, u.id] }, { include_blank: "Select person" }, class: "select select-bordered w-full" %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :assignment_type, "Role Type", class: "label" %>
    <%= form.select :assignment_type, RoleAssignment::ASSIGNMENT_TYPES.map { |t| [t.humanize, t] }, {}, class: "select select-bordered w-full" %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :starts_at, "Start Date", class: "label" %>
    <%= form.date_field :starts_at, class: "input input-bordered w-full", value: assignment.starts_at || Date.current %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :ends_at, "End Date (optional)", class: "label" %>
    <%= form.date_field :ends_at, class: "input input-bordered w-full", value: assignment.ends_at || (role.term_length_months ? Date.current + role.term_length_months.months : nil) %>
  </div>

  <div class="flex justify-end gap-2 mt-6">
    <%= link_to "Cancel", role_path(role), class: "btn btn-ghost" %>
    <%= form.submit "Assign", class: "btn btn-primary" %>
  </div>
<% end %>
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/role_assignments_controller_test.rb`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add app/controllers/role_assignments_controller.rb app/views/role_assignments/ test/controllers/role_assignments_controller_test.rb
git commit -m "Add role assignments controller for assigning users to roles"
```

---

## Task 8: Time Entries Controller

**Files:**
- Create: `app/controllers/time_entries_controller.rb`
- Create: `app/views/time_entries/new.html.erb`
- Create: `app/views/time_entries/_form.html.erb`
- Create: `app/views/time_entries/index.html.erb`
- Create: `test/controllers/time_entries_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/time_entries_controller_test.rb`:

```ruby
require "test_helper"

class TimeEntriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(@user)
    @role = roles(:garden_maven)
    @entry = time_entries(:maven_task_entry)
  end

  test "should get index" do
    get time_entries_url
    assert_response :success
  end

  test "should create task time entry" do
    task = tasks(:one)
    assert_difference("TimeEntry.count") do
      post role_time_entries_url(@role), params: { time_entry: {
        hours: 1.5,
        logged_on: Date.current,
        entry_type: "task",
        task_id: task.id
      } }
    end
    assert_redirected_to role_url(@role)
  end

  test "should create reconciliation entry" do
    assert_difference("TimeEntry.count") do
      post role_time_entries_url(@role), params: { time_entry: {
        hours: 3.0,
        logged_on: Date.current,
        entry_type: "reconciliation",
        note: "General maintenance conversations"
      } }
    end
    assert_redirected_to role_url(@role)
  end

  test "should destroy time entry" do
    assert_difference("TimeEntry.count", -1) do
      delete time_entry_url(@entry)
    end
    assert_redirected_to time_entries_url
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/time_entries_controller_test.rb`
Expected: Error — controller not found

- [ ] **Step 3: Create the controller**

Create `app/controllers/time_entries_controller.rb`:

```ruby
class TimeEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_role, only: [ :new, :create ]

  def index
    @time_entries = TimeEntry.for_user(current_user).recent.limit(50)
    @monthly_by_role = TimeEntry.for_user(current_user)
      .for_month(Date.current.year, Date.current.month)
      .group(:role_id)
      .sum(:hours)
    @roles = Role.where(id: @monthly_by_role.keys)
  end

  def new
    @time_entry = TimeEntry.new(role: @role, logged_on: Date.current, entry_type: "reconciliation")
    @tasks = @role.tasks.where(status: %w[active backlog])
  end

  def create
    @time_entry = TimeEntry.new(time_entry_params)
    @time_entry.user = current_user
    @time_entry.role = @role

    if @time_entry.save
      redirect_to role_url(@role), notice: "Time logged: #{@time_entry.hours} hours."
    else
      @tasks = @role.tasks.where(status: %w[active backlog])
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @time_entry = TimeEntry.find(params[:id])
    @time_entry.destroy
    redirect_to time_entries_url, notice: "Time entry removed."
  end

  private

  def set_role
    @role = Role.find(params[:role_id])
  end

  def time_entry_params
    params.require(:time_entry).permit(:hours, :logged_on, :entry_type, :task_id, :note)
  end
end
```

- [ ] **Step 4: Create views**

Create `app/views/time_entries/new.html.erb`:

```erb
<div class="<%= hotwire_native_app? ? '' : '-mx-2 sm:mx-0 px-2 sm:px-0' %>">
  <h1 class="text-xl font-bold mb-4">Log Time: <%= @role.title %></h1>
  <%= render "time_entries/form", time_entry: @time_entry, role: @role %>
</div>
```

Create `app/views/time_entries/_form.html.erb`:

```erb
<%= form_with(model: [ role, time_entry ]) do |form| %>
  <% if time_entry.errors.any? %>
    <div class="alert alert-error mb-4">
      <ul>
        <% time_entry.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="form-control w-full mb-4">
    <%= form.label :entry_type, "Type", class: "label" %>
    <%= form.select :entry_type, TimeEntry::ENTRY_TYPES.map { |t| [t.humanize, t] }, {}, class: "select select-bordered w-full" %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :hours, class: "label" %>
    <%= form.number_field :hours, class: "input input-bordered w-full", step: 0.25, min: 0.25, required: true %>
  </div>

  <div class="form-control w-full mb-4">
    <%= form.label :logged_on, "Date", class: "label" %>
    <%= form.date_field :logged_on, class: "input input-bordered w-full", required: true %>
  </div>

  <% if @tasks.any? %>
    <div class="form-control w-full mb-4">
      <%= form.label :task_id, "Task (optional)", class: "label" %>
      <%= form.select :task_id, @tasks.map { |t| [t.title, t.id] }, { include_blank: "No specific task" }, class: "select select-bordered w-full" %>
    </div>
  <% end %>

  <div class="form-control w-full mb-4">
    <%= form.label :note, "Note (optional)", class: "label" %>
    <%= form.text_field :note, class: "input input-bordered w-full", placeholder: "What did you work on?" %>
  </div>

  <div class="flex justify-end gap-2 mt-6">
    <%= link_to "Cancel", role_path(role), class: "btn btn-ghost" %>
    <%= form.submit "Log Time", class: "btn btn-primary" %>
  </div>
<% end %>
```

Create `app/views/time_entries/index.html.erb`:

```erb
<div class="<%= hotwire_native_app? ? '' : '-mx-2 sm:mx-0 px-2 sm:px-0' %>">
  <h1 class="text-xl sm:text-2xl font-bold mb-4">My Time</h1>

  <!-- Monthly Summary by Role -->
  <% if @monthly_by_role.any? %>
    <div class="mb-6">
      <h2 class="text-lg font-semibold mb-2">This Month</h2>
      <div class="space-y-2">
        <% @monthly_by_role.each do |role_id, hours| %>
          <% role = @roles.find { |r| r.id == role_id } %>
          <% next unless role %>
          <div class="flex justify-between items-center py-2 border-b border-base-200">
            <span class="font-medium text-sm"><%= role.title %></span>
            <span class="badge badge-ghost"><%= hours %> hrs</span>
          </div>
        <% end %>
      </div>
      <p class="text-right mt-2 font-bold">Total: <%= @monthly_by_role.values.sum %> hrs</p>
    </div>
  <% end %>

  <!-- Recent Entries -->
  <h2 class="text-lg font-semibold mb-2">Recent Entries</h2>
  <div class="space-y-2">
    <% @time_entries.each do |entry| %>
      <div class="card bg-base-100 border border-base-200 p-3">
        <div class="flex justify-between items-center">
          <div>
            <span class="font-medium text-sm"><%= entry.role&.title || "Unlinked" %></span>
            <span class="text-xs text-base-content/60 ml-2"><%= entry.logged_on.strftime("%b %d") %></span>
            <% if entry.note.present? %>
              <p class="text-xs text-base-content/60 mt-0.5"><%= entry.note %></p>
            <% end %>
          </div>
          <div class="flex items-center gap-2">
            <span class="badge badge-sm"><%= entry.hours %> hrs</span>
            <%= button_to "×", time_entry_path(entry), method: :delete, class: "btn btn-ghost btn-xs", data: { turbo_confirm: "Delete this time entry?" } %>
          </div>
        </div>
      </div>
    <% end %>
  </div>

  <div class="mt-6">
    <%= link_to "Back to Roles", roles_path, class: "btn btn-ghost btn-sm" %>
  </div>
</div>
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/time_entries_controller_test.rb`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add app/controllers/time_entries_controller.rb app/views/time_entries/ test/controllers/time_entries_controller_test.rb
git commit -m "Add time entries controller with logging and monthly summary"
```

---

## Task 9: Add Roles Entry Point to Tasks Tab

**Files:**
- Modify: `app/views/tasks/index.html.erb`
- Modify: `app/views/tasks/_form.html.erb`
- Create: `app/views/tasks/_role_select.html.erb`
- Modify: `test/system/roles_test.rb`

- [ ] **Step 1: Write the failing system test**

Create `test/system/roles_test.rb`:

```ruby
require "application_system_test_case"

class RolesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "navigating to roles from tasks tab" do
    visit tasks_url
    click_on "Roles"
    assert_text "Roles"
    assert_text "Garden Health Maven"
  end

  test "viewing role detail" do
    visit roles_url
    click_on "Garden Health Maven"
    assert_text "Garden Health Maven"
    assert_text "Duties"
  end

  test "creating a new role" do
    visit roles_url
    click_on "Add Role"
    fill_in "Title", with: "Test New Role"
    select "Community", from: "Category"
    fill_in "Term Length (months)", with: "6"
    fill_in "Duties (official responsibilities)", with: "Do important community things"
    click_on "Create Role"
    assert_text "Role was successfully created"
    assert_text "Test New Role"
  end

  test "assigning a user to a role" do
    role = roles(:facilitator)
    visit role_url(role)
    click_on "Assign Someone"
    select @user.name, from: "Person"
    select "Holder", from: "Role Type"
    click_on "Assign"
    assert_text "assigned as Holder"
  end

  test "logging time against a role" do
    role = roles(:garden_maven)
    visit role_url(role)
    click_on "Log Time"
    fill_in "Hours", with: "2.5"
    click_on "Log Time"
    assert_text "Time logged: 2.5 hours"
  end

  test "creating a task linked to a role" do
    visit tasks_url
    find("button[data-action='click->tasks#showForm']").click

    within "#new_task" do
      fill_in "task[title]", with: "Role-linked task"
      select "Garden Health Maven", from: "task[role_id]"
      click_on "Create Task"
    end

    assert_text "Task was successfully created"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/system/roles_test.rb`
Expected: Failure — "Roles" link not found on tasks page

- [ ] **Step 3: Add roles link to tasks header**

In `app/views/tasks/index.html.erb`, find the header `<div class="flex justify-between items-center gap-2">` and update it:

```erb
<div class="flex justify-between items-center gap-2">
  <h1 class="text-xl sm:text-2xl font-bold">Tasks</h1>
  <div class="flex items-center gap-2">
    <%= link_to roles_path, class: "btn btn-ghost btn-sm btn-square", title: "Community Roles" do %>
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
      </svg>
    <% end %>
    <button class="btn btn-primary btn-sm sm:btn-md" data-action="click->tasks#showForm">Add</button>
  </div>
</div>
```

- [ ] **Step 4: Add role select to task form**

Create `app/views/tasks/_role_select.html.erb`:

```erb
<div class="form-control w-full mb-4">
  <%= form.label :role_id, "Role (optional)", class: "label" %>
  <%= form.select :role_id, Role.ordered.map { |r| [r.title, r.id] }, { include_blank: "No role" }, class: "select select-bordered w-full" %>
</div>
```

In `app/views/tasks/_form.html.erb`, add after the user select section (or after due_date field):

```erb
<% if controller_name == 'tasks' %>
  <%= render "tasks/role_select", form: form %>
<% end %>
```

- [ ] **Step 5: Update set_users to include roles**

In `app/controllers/tasks_controller.rb`, update the `set_users` method (or add a new before_action):

```ruby
before_action :set_users, only: [ :index, :new, :edit, :create, :update ]
```

No change needed — roles are loaded in the partial via `Role.ordered`.

- [ ] **Step 6: Run system tests**

Run: `bin/rails test test/system/roles_test.rb`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add app/views/tasks/index.html.erb app/views/tasks/_form.html.erb app/views/tasks/_role_select.html.erb test/system/roles_test.rb
git commit -m "Add roles entry point to tasks tab and role select to task form"
```

---

## Task 10: Workload Sentiment

**Files:**
- Create: `db/migrate/TIMESTAMP_create_workload_sentiments.rb`
- Create: `app/models/workload_sentiment.rb`
- Create: `test/models/workload_sentiment_test.rb`
- Create: `test/fixtures/workload_sentiments.yml`
- Modify: `app/views/roles/show.html.erb` (add sentiment display)

- [ ] **Step 1: Write the failing test**

Create `test/models/workload_sentiment_test.rb`:

```ruby
require "test_helper"

class WorkloadSentimentTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @role = roles(:garden_maven)
  end

  test "should require user" do
    sentiment = WorkloadSentiment.new(role: @role, sentiment: "just_right", month: Date.current.beginning_of_month)
    assert_not sentiment.valid?
    assert_includes sentiment.errors[:user], "must exist"
  end

  test "should require role" do
    sentiment = WorkloadSentiment.new(user: @user, sentiment: "just_right", month: Date.current.beginning_of_month)
    assert_not sentiment.valid?
    assert_includes sentiment.errors[:role], "must exist"
  end

  test "should require sentiment" do
    sentiment = WorkloadSentiment.new(user: @user, role: @role, month: Date.current.beginning_of_month)
    assert_not sentiment.valid?
    assert_includes sentiment.errors[:sentiment], "can't be blank"
  end

  test "should validate sentiment inclusion" do
    sentiment = WorkloadSentiment.new(user: @user, role: @role, sentiment: "confused", month: Date.current.beginning_of_month)
    assert_not sentiment.valid?
    assert_includes sentiment.errors[:sentiment], "is not included in the list"
  end

  test "should allow valid sentiment" do
    sentiment = WorkloadSentiment.new(
      user: @user,
      role: @role,
      sentiment: "just_right",
      month: Date.current.beginning_of_month
    )
    assert sentiment.valid?
  end

  test "should enforce one sentiment per user per role per month" do
    WorkloadSentiment.create!(user: @user, role: @role, sentiment: "just_right", month: Date.current.beginning_of_month)
    duplicate = WorkloadSentiment.new(user: @user, role: @role, sentiment: "too_much", month: Date.current.beginning_of_month)
    assert_not duplicate.valid?
  end
end
```

- [ ] **Step 2: Create fixtures**

Create `test/fixtures/workload_sentiments.yml`:

```yaml
maven_sentiment:
  user: one
  role: garden_maven
  sentiment: just_right
  month: <%= Date.current.beginning_of_month %>
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/models/workload_sentiment_test.rb`
Expected: Error — `WorkloadSentiment` not found

- [ ] **Step 4: Create the migration**

Run: `bin/rails generate migration CreateWorkloadSentiments`

Edit the generated migration:

```ruby
class CreateWorkloadSentiments < ActiveRecord::Migration[8.0]
  def change
    create_table :workload_sentiments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.string :sentiment, null: false
      t.date :month, null: false
      t.timestamps
    end

    add_index :workload_sentiments, [ :user_id, :role_id, :month ], unique: true, name: "idx_workload_sentiments_unique"
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create the model**

Create `app/models/workload_sentiment.rb`:

```ruby
class WorkloadSentiment < ApplicationRecord
  belongs_to :user
  belongs_to :role

  SENTIMENTS = %w[too_much just_right too_little].freeze

  validates :sentiment, presence: true, inclusion: { in: SENTIMENTS }
  validates :month, presence: true
  validates :user_id, uniqueness: { scope: [ :role_id, :month ] }

  scope :for_month, ->(date) { where(month: date.beginning_of_month) }
  scope :for_role, ->(role) { where(role: role) }
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/models/workload_sentiment_test.rb`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*_create_workload_sentiments.rb app/models/workload_sentiment.rb test/models/workload_sentiment_test.rb test/fixtures/workload_sentiments.yml
git commit -m "Add WorkloadSentiment model for monthly workload self-assessment"
```

---

## Task 11: Recurring Task Generation Job

**Files:**
- Create: `app/jobs/generate_recurring_tasks_job.rb`
- Create: `test/jobs/generate_recurring_tasks_job_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/jobs/generate_recurring_tasks_job_test.rb`:

```ruby
require "test_helper"

class GenerateRecurringTasksJobTest < ActiveJob::TestCase
  def setup
    @template = recurring_task_templates(:grounds_walk)
    @holder = role_assignments(:maven_holder)
  end

  test "should generate task for due template" do
    @template.update!(last_generated_at: 3.weeks.ago.to_date)

    assert_difference("Task.count") do
      GenerateRecurringTasksJob.perform_now
    end

    task = Task.last
    assert_equal @template.title, task.title
    assert_equal @template.role, task.role
    assert_equal @holder.user, task.assigned_to_user
  end

  test "should not generate task for template not yet due" do
    @template.update!(last_generated_at: Date.current)

    assert_no_difference("Task.count") do
      GenerateRecurringTasksJob.perform_now
    end
  end

  test "should not generate task for role with no active holder" do
    @template.update!(last_generated_at: 3.weeks.ago.to_date)
    @holder.update!(active: false)

    assert_no_difference("Task.count") do
      GenerateRecurringTasksJob.perform_now
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/jobs/generate_recurring_tasks_job_test.rb`
Expected: Error — `GenerateRecurringTasksJob` not found

- [ ] **Step 3: Create the job**

Create `app/jobs/generate_recurring_tasks_job.rb`:

```ruby
class GenerateRecurringTasksJob < ApplicationJob
  queue_as :default

  def perform
    RecurringTaskTemplate.find_each do |template|
      next unless template.due_for_generation?

      holder = template.role.current_holders.first
      next unless holder

      template.generate_task!(holder.user)
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/jobs/generate_recurring_tasks_job_test.rb`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/jobs/generate_recurring_tasks_job.rb test/jobs/generate_recurring_tasks_job_test.rb
git commit -m "Add job to auto-generate tasks from recurring templates"
```

---

## Task 12: Final Integration — Run All Tests and Lint

**Files:** None new — verification only.

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass with no regressions

- [ ] **Step 2: Run rubocop**

Run: `bin/rubocop`
Expected: No offenses (fix any that appear)

- [ ] **Step 3: Run brakeman**

Run: `bin/brakeman --no-pager`
Expected: No new warnings

- [ ] **Step 4: Commit any lint fixes**

```bash
git add -A
git commit -m "Fix lint offenses from roles and time tracking implementation"
```

---

## Summary

| Task | What it builds |
|------|---------------|
| 1 | Role model + migration |
| 2 | RoleAssignment model (holder/backup/co_holder, terms) |
| 3 | TimeEntry model (per-task + reconciliation) |
| 4 | RecurringTaskTemplate model |
| 5 | Link tasks to roles (add role_id FK) |
| 6 | Roles controller + views (directory, detail, CRUD) |
| 7 | Role assignments controller (assign/unassign) |
| 8 | Time entries controller (log, view, monthly summary) |
| 9 | UI integration (entry point in tasks tab, role select on task form) |
| 10 | Workload sentiment model |
| 11 | Recurring task generation job |
| 12 | Final verification (tests, lint, security) |
