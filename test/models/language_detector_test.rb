require "test_helper"

class LanguageDetectorTest < ActiveSupport::TestCase
  test "detects english from stopword frequency" do
    assert_equal :en, LanguageDetector.detect("the system is designed for operators and this guide covers the basics of the tool")
  end

  test "detects french from stopword frequency" do
    assert_equal :fr, LanguageDetector.detect("le guide décrit les membranes de toiture et la pose est une étape du bâtiment pour les auxiliaires que les équipes utilisent")
  end

  test "empty or wordless input defaults to en" do
    assert_equal :en, LanguageDetector.detect("")
    assert_equal :en, LanguageDetector.detect("123 456 !!!")
  end

  test "a tie defaults to en" do
    assert_equal :en, LanguageDetector.detect("le the")
  end

  test "scores under the floor default to en" do
    assert_equal :en, LanguageDetector.detect("xyzzy plugh quux xyzzy")
  end
end
