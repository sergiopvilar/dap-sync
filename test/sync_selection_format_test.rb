#!/usr/bin/env ruby
require 'minitest/autorun'
require 'fileutils'

# Mock the app functions for testing
module SyncSelectionFormatTestHelpers
  # Mock configuration constants
  MUSIC_SOURCE = '/music'
  AUDIOBOOKS_SOURCE = '/audiobooks'
  MUSIC_DIRECTORY = '/Users/sergio/Music/Music/Media.localized/Music/'
  AUDIOBOOKS_DIRECTORY = '/Users/sergio/Library/OpenAudible/books/'
  
  def convert_to_host_path(path, container_source, host_directory)
    # Normalize container_source to remove trailing slash for comparison
    container_base = container_source.end_with?('/') ? container_source[0..-2] : container_source
    container_prefix = "#{container_base}/"
    
    # Normalize host_directory to ensure it ends with /
    host_dir = host_directory.end_with?('/') ? host_directory : "#{host_directory}/"
    
    # If path already starts with host_directory, return as-is
    return path if path.start_with?(host_dir)
    
    # Remove container path prefix if present (e.g., /music/ or /audiobooks/)
    if path.start_with?(container_prefix)
      relative_path = path[container_prefix.length..-1]
    elsif path.start_with?('/music/')
      relative_path = path[7..-1]
    elsif path.start_with?('/audiobooks/')
      relative_path = path[12..-1]
    elsif path.start_with?('/')
      # Already absolute but not container path - assume it's already a host path
      return path
    else
      # Relative path
      relative_path = path
    end
    
    # Remove leading slash from relative_path if present
    relative_path = relative_path[1..-1] if relative_path.start_with?('/')
    
    "#{host_dir}#{relative_path}"
  end
  
  def write_sync_selection_test(music_mode, music_albums, audiobooks_mode, audiobooks_list, file_path, mock_albums = [], mock_audiobooks = [])
    FileUtils.mkdir_p(File.dirname(file_path))
    
    File.open(file_path, 'w') do |f|
      # Write music albums (all albums if mode is "all", selected albums otherwise)
      if music_mode == "all"
        # Use mock albums if provided, otherwise use music_albums
        albums_to_write = mock_albums.empty? ? music_albums : mock_albums
        albums_to_write.each do |album|
          album_path = album.is_a?(Hash) ? convert_to_host_path(album[:path], MUSIC_SOURCE, MUSIC_DIRECTORY) : convert_to_host_path(album, MUSIC_SOURCE, MUSIC_DIRECTORY)
          f.puts "MUSIC_ALBUM=#{album_path}"
        end
      else
        # Write selected albums
        music_albums.each do |path|
          album_path = convert_to_host_path(path, MUSIC_SOURCE, MUSIC_DIRECTORY)
          f.puts "MUSIC_ALBUM=#{album_path}"
        end
      end
      
      # Write audiobooks (all audiobooks if mode is "all", selected audiobooks otherwise)
      if audiobooks_mode == "all"
        # Use mock audiobooks if provided, otherwise use audiobooks_list
        audiobooks_to_write = mock_audiobooks.empty? ? audiobooks_list : mock_audiobooks
        audiobooks_to_write.each do |ab|
          audiobook_path = ab.is_a?(Hash) ? convert_to_host_path(ab[:path], AUDIOBOOKS_SOURCE, AUDIOBOOKS_DIRECTORY) : convert_to_host_path(ab, AUDIOBOOKS_SOURCE, AUDIOBOOKS_DIRECTORY)
          f.puts "AUDIOBOOKS=#{audiobook_path}"
        end
      else
        # Write selected audiobooks
        audiobooks_list.each do |path|
          audiobook_path = convert_to_host_path(path, AUDIOBOOKS_SOURCE, AUDIOBOOKS_DIRECTORY)
          f.puts "AUDIOBOOKS=#{audiobook_path}"
        end
      end
    end
  end
end

class SyncSelectionFormatTest < Minitest::Test
  include SyncSelectionFormatTestHelpers
  
  TEST_SELECTION_FILE = '/tmp/test_sync_selection_format.txt'
  
  def setup
    File.delete(TEST_SELECTION_FILE) if File.exist?(TEST_SELECTION_FILE)
  end
  
  def teardown
    File.delete(TEST_SELECTION_FILE) if File.exist?(TEST_SELECTION_FILE)
  end

  def test_writes_host_paths_for_music_albums
    # Test: Music albums should be written with MUSIC_DIRECTORY (host path), not container path
    relative_albums = ["Artist1/Album1", "Artist2/Album2"]
    
    write_sync_selection_test("selected", relative_albums, "all", [], TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist1\/Album1$/, content)
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist2\/Album2$/, content)
    refute_match(/\/music\//, content, "Should not contain container path /music/")
  end

  def test_writes_host_paths_for_audiobooks
    # Test: Audiobooks should be written with AUDIOBOOKS_DIRECTORY (host path), not container path
    relative_audiobooks = ["Book1.m4b", "Book2.m4b"]
    
    write_sync_selection_test("all", [], "selected", relative_audiobooks, TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^AUDIOBOOKS=\/Users\/sergio\/Library\/OpenAudible\/books\/Book1\.m4b$/, content)
    assert_match(/^AUDIOBOOKS=\/Users\/sergio\/Library\/OpenAudible\/books\/Book2\.m4b$/, content)
    refute_match(/\/audiobooks\//, content, "Should not contain container path /audiobooks/")
  end

  def test_converts_container_paths_to_host_paths
    # Test: If paths come with container prefix, they should be converted to host paths
    container_music_paths = ["/music/Artist1/Album1", "/music/Artist2/Album2"]
    container_audiobook_paths = ["/audiobooks/Book1.m4b"]
    
    write_sync_selection_test("selected", container_music_paths, "selected", container_audiobook_paths, TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist1\/Album1$/, content)
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist2\/Album2$/, content)
    assert_match(/^AUDIOBOOKS=\/Users\/sergio\/Library\/OpenAudible\/books\/Book1\.m4b$/, content)
    refute_match(/\/music\//, content)
    refute_match(/\/audiobooks\//, content)
  end

  def test_preserves_host_paths_if_already_host_paths
    # Test: If paths are already host paths, they should be preserved
    host_music_paths = ["/Users/sergio/Music/Music/Media.localized/Music/Artist1/Album1"]
    host_audiobook_paths = ["/Users/sergio/Library/OpenAudible/books/Book1.m4b"]
    
    write_sync_selection_test("selected", host_music_paths, "selected", host_audiobook_paths, TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist1\/Album1$/, content)
    assert_match(/^AUDIOBOOKS=\/Users\/sergio\/Library\/OpenAudible\/books\/Book1\.m4b$/, content)
  end

  def test_writes_all_albums_with_host_paths
    # Test: When mode is "all", all albums should be written with host paths
    mock_albums = [
      { path: "Artist1/Album1" },
      { path: "Artist2/Album2" }
    ]
    
    write_sync_selection_test("all", [], "all", [], TEST_SELECTION_FILE, mock_albums, [])
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist1\/Album1$/, content)
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist2\/Album2$/, content)
    refute_match(/\/music\//, content)
  end

  def test_writes_all_audiobooks_with_host_paths
    # Test: When mode is "all", all audiobooks should be written with host paths
    mock_audiobooks = [
      { path: "Book1.m4b" },
      { path: "Book2.m4b" }
    ]
    
    write_sync_selection_test("all", [], "all", [], TEST_SELECTION_FILE, [], mock_audiobooks)
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^AUDIOBOOKS=\/Users\/sergio\/Library\/OpenAudible\/books\/Book1\.m4b$/, content)
    assert_match(/^AUDIOBOOKS=\/Users\/sergio\/Library\/OpenAudible\/books\/Book2\.m4b$/, content)
    refute_match(/\/audiobooks\//, content)
  end

  def test_handles_paths_with_special_characters
    # Test: Paths with special characters (spaces, parentheses, etc.) should be handled correctly
    special_paths = [
      "A Banda de Joseph Tourton/A Banda de Joseph Tourton",
      "Artist (Live)/Album Name"
    ]
    
    write_sync_selection_test("selected", special_paths, "all", [], TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/A Banda de Joseph Tourton\/A Banda de Joseph Tourton$/, content)
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist \(Live\)\/Album Name$/, content)
  end

  def test_handles_flat_album_structure
    # Test: Flat album structure (no artist subdirectory) should work
    flat_albums = ["Album Name"]
    
    write_sync_selection_test("selected", flat_albums, "all", [], TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Album Name$/, content)
  end

  def test_format_has_no_extra_whitespace
    # Test: Format should not have extra whitespace around paths
    albums = ["Artist1/Album1"]
    
    write_sync_selection_test("selected", albums, "all", [], TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    lines = content.lines.map(&:strip).reject(&:empty?)
    lines.each do |line|
      assert_match(/^(MUSIC_ALBUM|AUDIOBOOKS)=[^ ]/, line, "Line should not have space after =")
      assert_match(/[^ ]$/, line, "Line should not end with space")
    end
  end

  def test_each_album_on_separate_line
    # Test: Each album/audiobook should be on a separate line
    albums = ["Artist1/Album1", "Artist2/Album2", "Artist3/Album3"]
    audiobooks = ["Book1.m4b", "Book2.m4b"]
    
    write_sync_selection_test("selected", albums, "selected", audiobooks, TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    music_lines = content.lines.select { |l| l.start_with?('MUSIC_ALBUM=') }
    audiobook_lines = content.lines.select { |l| l.start_with?('AUDIOBOOKS=') }
    
    assert_equal 3, music_lines.length, "Should have 3 music album lines"
    assert_equal 2, audiobook_lines.length, "Should have 2 audiobook lines"
  end

  def test_no_music_mode_or_audiobooks_mode_lines
    # Test: File should not contain MUSIC_MODE= or AUDIOBOOKS_MODE= lines
    albums = ["Artist1/Album1"]
    audiobooks = ["Book1.m4b"]
    
    write_sync_selection_test("selected", albums, "selected", audiobooks, TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    refute_match(/MUSIC_MODE=/, content, "Should not contain MUSIC_MODE=")
    refute_match(/AUDIOBOOKS_MODE=/, content, "Should not contain AUDIOBOOKS_MODE=")
  end

  def test_empty_selection_writes_nothing
    # Test: Empty selection should write empty file (or no MUSIC_ALBUM/AUDIOBOOKS lines)
    write_sync_selection_test("selected", [], "selected", [], TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    refute_match(/MUSIC_ALBUM=/, content)
    refute_match(/AUDIOBOOKS=/, content)
  end

  def test_paths_use_correct_host_directories
    # Test: Verify that paths use the exact MUSIC_DIRECTORY and AUDIOBOOKS_DIRECTORY values
    albums = ["Artist1/Album1"]
    audiobooks = ["Book1.m4b"]
    
    write_sync_selection_test("selected", albums, "selected", audiobooks, TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^MUSIC_ALBUM=#{Regexp.escape(MUSIC_DIRECTORY)}/, content)
    assert_match(/^AUDIOBOOKS=#{Regexp.escape(AUDIOBOOKS_DIRECTORY)}/, content)
  end

  def test_converts_container_paths_with_trailing_slash
    # Test: Container paths with trailing slash should be handled correctly
    container_paths = ["/music/Artist1/Album1/", "/audiobooks/Book1.m4b/"]
    
    write_sync_selection_test("selected", container_paths, "selected", [], TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    # Should convert to host path without double slashes
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist1\/Album1\/$/, content)
  end

  def test_handles_relative_paths_without_leading_slash
    # Test: Relative paths without leading slash should work
    relative_paths = ["Artist1/Album1", "Book1.m4b"]
    
    write_sync_selection_test("selected", [relative_paths[0]], "selected", [relative_paths[1]], TEST_SELECTION_FILE)
    content = File.read(TEST_SELECTION_FILE)
    
    assert_match(/^MUSIC_ALBUM=\/Users\/sergio\/Music\/Music\/Media\.localized\/Music\/Artist1\/Album1$/, content)
    assert_match(/^AUDIOBOOKS=\/Users\/sergio\/Library\/OpenAudible\/books\/Book1\.m4b$/, content)
  end
end
