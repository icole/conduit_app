# The window (a calendar quarter or half-year) over which the community looks
# at how work was shared.
class ContributionPeriod
  TYPES = { "quarterly" => 3, "semi_annual" => 6 }.freeze

  attr_reader :start_date, :type

  def self.containing(date, type)
    months = TYPES.fetch(type)
    start_month = ((date.month - 1) / months) * months + 1
    new(Date.new(date.year, start_month, 1), type)
  end

  def initialize(start_date, type)
    @start_date = start_date
    @type = type
  end

  def months = TYPES.fetch(type)
  def end_date = (start_date >> months) - 1
  def range = start_date..end_date
  def previous = self.class.new(start_date << months, type)
  def next = self.class.new(start_date >> months, type)
  def current?(today = Date.current) = range.cover?(today)
  def future?(today = Date.current) = start_date > today

  # "Jan – Jun 2026"
  def label
    "#{start_date.strftime('%b')} – #{end_date.strftime('%b %Y')}"
  end

  def ==(other)
    other.is_a?(self.class) && other.start_date == start_date && other.type == type
  end
end
