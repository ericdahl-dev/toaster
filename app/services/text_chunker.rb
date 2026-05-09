# frozen_string_literal: true

class TextChunker
  CHUNK_SIZE = 500
  OVERLAP = 50

  def self.call(text)
    words = text.split
    return [] if words.empty?

    chunks = []
    start = 0

    while start < words.length
      slice = words[start, CHUNK_SIZE]
      chunks << slice.join(" ")
      break if slice.length < CHUNK_SIZE

      start += CHUNK_SIZE - OVERLAP
    end

    chunks
  end
end
