#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

class SSRNImporter
  SSRN_BASE_URL = "http://ssrn.com/abstract="

  def initialize
    files.each do |f|
      get_metadata File.basename(f)
    end
  end

  def files
    if !ARGV.empty?
      if File.directory?(ARGV[0])
        Dir.chdir(ARGV[0])
        Dir.glob('*')
      else
        ARGV
      end
    else
      Dir.glob('*')
    end.find_all { |f| f.match /^SSRN.+\.pdf$/i }
  end

  def get_metadata(filename)
    md = {}

    md[:filename] = filename
    md[:ssrn_id]  = filename.match(/\d+/)[0]
    md[:ssrn_url] = SSRN_BASE_URL + md[:ssrn_id]

    ssrn_page = Nokogiri::HTML(open(md[:ssrn_url]))

    md[:title] = ssrn_page.css("#abstractTitle h1").text().strip || "Untitled"
    md[:authors] = []
    ssrn_page.css("a[title='View other papers by this author'] h2").each do |a|
      md[:authors] << a.text().strip || ""
    end

    md[:keywords] = ssrn_page.xpath("//b[contains(., 'Keywords:')]/following-sibling::text()").text().strip || ""

    set_metadata md

    new_title = (md[:title].match /[^0-9A-Za-z\-]/).nil? ?
      md[:title] :
      md[:title].gsub!(/[^0-9A-Za-z\-]/, '-')

    File.rename(filename, new_title + ".pdf")
  end

  def set_metadata(md)
    `xattr -w "com.apple.metadata:kMDItemTitle" "#{md[:title]}" #{md[:filename]}`
    `xattr -w "com.apple.metadata:kMDItemAuthors" "#{md[:authors].join(", ")}" #{md[:filename]}`
    `xattr -w "com.apple.metadata:kMDItemKeywords" "#{md[:keywords]}" #{md[:filename]}`
  end
end

SSRNImporter.new
