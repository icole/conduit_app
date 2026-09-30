require "test_helper"

# DaisyUI 5 renamed some classes. The old names do nothing, silently: the
# meal pages' initials avatars lost their centring when "placeholder"
# became "avatar-placeholder".
class DaisyuiClassNamesTest < ActiveSupport::TestCase
  RENAMED = {
    /\bavatar placeholder\b/ => "avatar avatar-placeholder",
    /\bavatar <%=.*'placeholder'/ => "avatar avatar-placeholder" # added conditionally
  }.freeze

  test "views use DaisyUI 5 class names" do
    stale = Dir[Rails.root.join("app/views/**/*.erb")].flat_map do |path|
      File.readlines(path).each_with_index.filter_map do |line, index|
        RENAMED.each_key.find { |old| line.match?(old) } && "#{path.delete_prefix("#{Rails.root}/")}:#{index + 1}"
      end
    end
    assert_empty stale, "Use #{RENAMED.values.join(', ')} (DaisyUI 5)"
  end
end
