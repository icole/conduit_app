// Text formatting utilities
export class TextHelpers {
  // Converts a string to title case, keeping small words lowercase
  // Matches the Rails proper_title_case helper functionality
  static properTitleCase(text) {
    if (!text || typeof text !== 'string') return text

    // Words that should remain lowercase in titles (unless they're the first or last word)
    // This matches the Rails helper's small_words list
    const smallWords = ['a', 'an', 'and', 'as', 'at', 'but', 'by', 'en', 'for', 'if', 'in', 'of', 'on', 'or', 'the', 'to', 'v', 'v.', 'via', 'vs', 'vs.', 'with']

    return text.toLowerCase().split(' ').map((word, index, arr) => {
      // Capitalize first word, last word, or non-small words
      if (index === 0 || index === arr.length - 1 || !smallWords.includes(word.toLowerCase())) {
        return word.charAt(0).toUpperCase() + word.slice(1)
      }
      return word.toLowerCase()
    }).join(' ')
  }

  // Format relative time (e.g., "2 hours ago")
  static timeAgo(dateString) {
    const date = new Date(dateString)
    const now = new Date()
    const diffInSeconds = Math.floor((now - date) / 1000)

    if (diffInSeconds < 60) return 'just now'
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)} minutes ago`
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)} hours ago`
    if (diffInSeconds < 2592000) return `${Math.floor(diffInSeconds / 86400)} days ago`
    return `${Math.floor(diffInSeconds / 2592000)} months ago`
  }
}
