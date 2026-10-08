require "test_helper"

# The apps' toolbars, tab bars and chat sit right against the website's pages,
# so their colours must be the website's exactly. Each native palette names
# them as hex; this reads the theme's oklch values and converts them, so a
# retuned theme that forgets the apps fails here, not on someone's phone.
class NativePaletteTest < ActiveSupport::TestCase
  THEME = Rails.root.join("app/assets/tailwind/theme.css").read
  ANDROID = Rails.root.join("android/app/src/main/java/com/colecoding/conduit/ui/Palette.kt")
  IOS = Rails.root.join("ios/Conduit/Conduit/Views/Palette.swift")

  { "paper" => "--color-paper", "ink" => "--color-base-content", "green" => "--color-primary" }.each do |name, token|
    test "the apps' #{name} is the website's #{token}" do
      hex = oklch_hex(token)
      assert_includes ANDROID.read, "0xFF#{hex}", "Palette.kt #{name} should be ##{hex}"
      assert_match(/#{name}\s*=\s*UIColor\(hex: 0x#{hex}\)/, IOS.read, "Palette.swift #{name} should be ##{hex}")
    end
  end

  # Chat is drawn by Stream's SDK on each platform; both get the same colours
  %w[surface muted line greenTint].each do |name|
    test "iOS and Android chat share the #{name} colour" do
      android = ANDROID.read[/val #{name} = 0xFF(\h{6})/, 1]
      assert android, "Palette.kt has no #{name}"
      assert_match(/#{name}\s*=\s*UIColor\(hex: 0x#{android}\)/, IOS.read, "Palette.swift #{name} should be ##{android}")
    end
  end

  # The palette is light only, as the website is: in dark mode Stream's own
  # night colours would come back under ours (on Android, black names on black)
  test "the iOS app stays in light mode whatever the phone is set to" do
    assert_includes Rails.root.join("ios/Conduit/Conduit/App/SceneDelegate.swift").read, "window.overrideUserInterfaceStyle = .light"
  end

  private

  def oklch_hex(token)
    l, c, h = THEME.match(/#{Regexp.escape(token)}:\s*oklch\(([\d.]+)%\s+([\d.]+)\s+([\d.]+)\)/).captures.map(&:to_f)
    a = c * Math.cos(h * Math::PI / 180)
    b = c * Math.sin(h * Math::PI / 180)
    l /= 100
    lms = [ l + 0.3963377774 * a + 0.2158037573 * b, l - 0.1055613458 * a - 0.0638541728 * b, l - 0.0894841775 * a - 1.2914855480 * b ].map { |v| v**3 }
    rgb = [
      4.0767416621 * lms[0] - 3.3077115913 * lms[1] + 0.2309699292 * lms[2],
      -1.2684380046 * lms[0] + 2.6097574011 * lms[1] - 0.3413193965 * lms[2],
      -0.0041960863 * lms[0] - 0.7034186147 * lms[1] + 1.7076147010 * lms[2]
    ]
    rgb.map { |v| v = v.clamp(0, 1); (v <= 0.0031308 ? 12.92 * v : 1.055 * v**(1 / 2.4) - 0.055) }
       .map { |v| format("%02X", (v * 255).round) }.join
  end
end
