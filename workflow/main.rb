#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems' unless defined? Gem # rubygems is only needed in 1.8
require_relative 'bundle/bundler/setup'
require 'alfred'
require 'sqlite3'
require 'optparse'

Alfred.with_friendly_error do |alfred|
  fb = alfred.feedback

  options = {}
  OptionParser.new do |opts|
    opts.on('--random"') do |random|
      options[:random] = random
    end
  end.parse!

  STDERR.puts options

  db_paths = `mdfind -name readitLater3.sqlite`
  db_path = db_paths.lines[0].chomp
  copy_db_path = db_path + ".copy"
  FileUtils.cp db_path, copy_db_path
  db = SQLite3::Database.open(copy_db_path)

  query = <<-SQL
    SELECT title, url, item_id
    FROM items
  SQL

  if ARGV.length > 0
    url_queries = []
    title_queries = []
    excerpt_queries = []

    ARGV.each do |word|
      url_queries.push "url LIKE '%#{word}%'"
      title_queries.push "title LIKE '%#{word}%'"
      excerpt_queries.push "excerpt LIKE '%#{word}%'"
    end

    query += <<-SQL
      WHERE #{url_queries.join(' AND ')}
      OR #{title_queries.join(' AND ')}
      OR #{excerpt_queries.join(' AND ')}
    SQL
  end

  if options[:random]
    query += ' ORDER BY random()'
  else
    query += ' ORDER BY time_added DESC'
  end

  query += ' LIMIT 100'

  STDERR.puts query

  db.execute(query) do |row|
    title = row[0]
    url = row[1]
    item_id = row[2]

    fb.add_item({
      uid: 'pocket.result',
      title: title,
      subtitle: url,
      arg: 'https://getpocket.com/a/read/' + item_id.to_s,
      valid: 'yes'
    })
  end

  puts fb.to_xml

  db.close
end
