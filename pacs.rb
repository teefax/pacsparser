#!/usr/bin/env ruby
# 
# parse PACS2008 file and do things with it
require 'rubygems'
require 'open-uri'
require 'pp'

# PACS = "http://www.aip.org/pacs/pacs08/ASCII2008FullPacs.txt"
PACS = "ASCII2008FullPacs.txt"

lines = open(PACS).read
lines.sort{|a,b| a.casecmp(b)}
@pacs = {}

lines.scan(/^(\d{2})\.(\d{2})\.(..) (.*)$/) do |l|
  (first, second, third, desc) = l
  begin
    if first.to_i % 10 == 0
      @pacs[first] ||= {} # create sub-hash if needed
      @pacs[first][:desc] = desc
      next
    elsif second.to_i == 0
      @pacs[first] ||= {} # create sub-hash if needed
      @pacs[first][second] ||= {} # create sub-hash if needed
      @pacs[first][second][:desc] = desc
      next
    else
      @pacs[first] ||= {} # create sub-hash if needed
      @pacs[first][second] ||= {} # create sub-hash if needed
      @pacs[first][second][third] ||= {} # create sub-hash if needed

      if third.match(/^\+/)
        # no sub category
        @pacs[first][second][third][:desc] = desc
      elsif third.match(/^\-/)
        # start a sub-section, everything until the next (the lines are sorted accordingly) -?
        # third group is in that subgroup
        @pacs[first][second][third][third[1]] ||= {}
        @pacs[first][second][third][:desc] = desc
      end

    end    
  rescue Exception => e
    puts "Error in line '#{l}': #{e}"
  end
  
end

@pacs.keys.sort{|a,b| a.casecmp(b)}.each do |k|
  if @pacs[k][:desc]
    # toplevel category
    puts "#{k}: #{@pacs[k][:desc]}"
  else
    @pacs[k].keys.sort{|a,b| a.casecmp(b)}.each do |sk|
      if @pacs[k][sk][:desc]
        puts "\t#{k}.#{sk}: #{@pacs[k][sk][:desc]}"
      else
        @pacs[k][sk].keys.sort{|a,b| a.casecmp(b)}.each do |ssk|
          puts "\t\t#{k}.#{sk}.#{ssk}: #{@pacs[k][sk][ssk][:desc]}"
        end
      end
    end
  end
end
