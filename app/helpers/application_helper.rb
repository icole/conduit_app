module ApplicationHelper
  # Converts a string to title case, keeping small words lowercase
  # Example: "meeting with john and jane at the office" becomes "Meeting with John and Jane at the Office"
  def proper_title_case(text)
    return text unless text.is_a?(String)

    # Words that should remain lowercase in titles (unless they're the first or last word)
    small_words = %w[a an and as at but by en for if in of on or the to v v. via vs vs. with]

    # Split the text into words and capitalize each word unless it's a small word
    result = text.downcase.split.map.with_index do |word, index|
      # Capitalize first word, last word, or non-small words
      if index == 0 || index == text.split.size - 1 || !small_words.include?(word.downcase)
        word.capitalize
      else
        word.downcase
      end
    end

    result.join(" ")
  end
end
