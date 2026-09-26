require "test_helper"

# The Content-Security-Policy sets no `unsafe-inline` for scripts, so inline
# JavaScript in a template is dead code in the browser — silently. The browser
# gate in test/system/content_security_policy_test.rb catches this on the pages
# it visits; this catches it everywhere, including templates no test opens
# (chat/native_prompt is the iOS bridge, and calendar_shares/success needs a
# real Google share to reach).
class InlineJavascriptTest < ActiveSupport::TestCase
  VIEWS = Rails.root.join("app/views")

  # An `on*=` attribute cannot be rescued by a nonce — the policy has no way to
  # vouch for an attribute. These have to become Stimulus actions.
  EVENT_ATTRIBUTE = /\son(?:click|change|submit|input|load|error|focus|blur|keyup|keydown|mouseover|mouseout)\s*=/

  # `javascript_tag nonce: true` renders a nonced tag; a literal <script> cannot.
  LITERAL_SCRIPT_TAG = /<script(?:\s|>)/

  test "no templates use inline event handler attributes" do
    assert_empty offenders(EVENT_ATTRIBUTE),
      "Inline event handlers are blocked by the Content-Security-Policy. " \
      "Move them into a Stimulus controller:"
  end

  test "no templates use literal script tags" do
    assert_empty offenders(LITERAL_SCRIPT_TAG),
      "A literal <script> tag carries no nonce and is blocked by the " \
      "Content-Security-Policy. Use `javascript_tag nonce: true` instead:"
  end

  private

  def offenders(pattern)
    Dir.glob(VIEWS.join("**/*.erb")).sort.flat_map do |path|
      File.readlines(path).each_with_index.filter_map do |line, index|
        "#{Pathname(path).relative_path_from(Rails.root)}:#{index + 1}" if line.match?(pattern)
      end
    end
  end
end
