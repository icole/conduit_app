# Effort is sized Small, Medium or Large rather than typed in minutes. Each
# size stands for a number of minutes, which is what counts toward
# contribution. A task that already has agreed minutes (say 150, from the
# community's spreadsheet) keeps them for as long as its size stays the same.
module EstimatedEffort
  extend ActiveSupport::Concern

  SIZES = { "Small" => 15, "Medium" => 45, "Large" => 90 }.freeze

  def self.size_for(minutes)
    return if minutes.blank?

    if minutes < 30 then "Small"
    elsif minutes < 60 then "Medium"
    else "Large"
    end
  end

  def effort = EstimatedEffort.size_for(estimated_minutes)

  def effort=(size)
    if size.blank?
      self.estimated_minutes = nil
    elsif SIZES.key?(size) && size != effort
      self.estimated_minutes = SIZES[size]
    end
  end
end
