# Stopword-frequency language scoring for ingest (one job: en/fr detection).
#
# STOPWORDS are duplicated INLINE in the 20260916100000 migration backfill —
# fresh db:migrate replays must not depend on this PORO. Keep both lists in
# sync when adding a language (plus a tsv config term, see the plan's
# Constraints note).
class LanguageDetector
  STOPWORDS = {
    en: %w[the and of to in is for that with are this be on],
    fr: %w[le la les de des du et est une un dans pour que qui pas au aux]
  }.freeze

  WORD = /\p{L}+/
  private_constant :WORD

  WORD_LIMIT = 2000
  MIN_SCORE = 0.01
  private_constant :WORD_LIMIT, :MIN_SCORE

  # Score = stopword hits / total words over the first ~2000 words.
  # Empty input, a tie, or all scores under MIN_SCORE default to :en.
  def self.detect(text)
    words = text.to_s.downcase.scan(WORD).first(WORD_LIMIT)
    return :en if words.empty?

    scores = STOPWORDS.transform_values { |stopwords| words.count { |word| stopwords.include?(word) }.fdiv(words.size) }
    best = scores.max_by { |_language, score| score }
    return :en if best[1] < MIN_SCORE

    best[0] # tie resolves to :en: it leads the STOPWORDS map
  end
end
