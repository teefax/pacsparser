#!/usr/bin/env ruby -wKU
# 
# parse PACS2008 file and do things with it
require 'open-uri'
require "strscan"

# PACSFILE = "http://www.aip.org/pacs/pacs08/ASCII2008FullPacs.txt"
PACSFILE = "ASCII2008FullPacs.txt"

class PACSParser
  PACS = Struct.new(:id, :desc, :children)

  def initialize
    @container = Array.new
  end
  
  def load
    begin
      f = File.open(PACSFILE,'r')
      @lines = f.read
      f.close
      # @lines.sort{|a,b| a.casecmp(b)}.to_s
      @lines
    rescue Exception => e
      puts "Error loading file: #{e}"
    end    
  end
  
  def parse(input)
    @input = StringScanner.new(input)
    begin
      while !@input.eos?
        trim_space ||
        parse_content
      end
    rescue Exception => e
      puts "Error: #{e} at #{@input.peek(@input.string.length)}"
    end
  end
  
  def print
    @container.each do |i|
      print_pacs(i)
    end
  end
  
  def print_pacs(pacs, indent = "")
    puts "#{indent}#{pacs.id} #{pacs.desc}"
    if !pacs.children.nil?
      pacs.children.each do |c|
        print_pacs(c, indent+"\t")
      end
    end
  end
  
  private
  
  def parse_content
    @current_id = nil
    parse_pacs or
    parse_comment or
    ignore
  end
  
  def parse_pacs
    if @input.scan(/(\d{2})\.(\d{2}).(..) (.*)\n/)
      current_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
      desc = @input[4]
      
      if @input[1].to_i % 10 == 0
        # if top-level-element
        @container.push PACS.new(current_id, desc)
        
      else
        tl = @container[@input[1].to_i/10.round]
        tl.children ||= []
        tl.children.push PACS.new(current_id, desc)
      end
      
      
      true
    else
      false
    end
  end
  
  def parse_comment
    if @input.scan(/\.{3} \.{3} (.*)\n/)
      # do nothing for the moment
      true
    else
      false
    end
  end
  
  def ignore
    if @input.scan(/(.*)\n/)
      # puts "Ignoring '#{@input[1]}'"
    else
      false
    end
  end
  
  def trim_space
    @input.scan(/\s+/)
  end
  
  def trim_newline
    @input.scan(/\n/)
  end
  
  def error(message)
    if @input.eos?
      raise "Unexpected end of input."
    else
      raise "#{message}: '#{@input.peek(@input.string.length)}'"
    end
  end
end


p = PACSParser.new
p.parse(p.load)
p.print

# lines.scan(/^(\d{2})\.(\d{2})\.(..) (.*)$/) do |l|
#   (first, second, third, desc) = l
#   begin
#     if first.to_i % 10 == 0
#       @pacs[first] ||= {} # create sub-hash if needed
#       @pacs[first][:desc] = desc
#       next
#     elsif second.to_i == 0
#       @pacs[first] ||= {} # create sub-hash if needed
#       @pacs[first][second] ||= {} # create sub-hash if needed
#       @pacs[first][second][:desc] = desc
#       next
#     else
#       @pacs[first] ||= {} # create sub-hash if needed
#       @pacs[first][second] ||= {} # create sub-hash if needed
#       @pacs[first][second][third] ||= {} # create sub-hash if needed
# 
#       if third.match(/^\+/)
#         # no sub category
#         @pacs[first][second][third][:desc] = desc
#       elsif third.match(/^\-/)
#         # start a sub-section, everything until the next (the lines are sorted accordingly) -?
#         # third group is in that subgroup
#         @pacs[first][second][third][third[1]] ||= {}
#         @pacs[first][second][third][:desc] = desc
#       end
# 
#     end    
#   rescue Exception => e
#     puts "Error in line '#{l}': #{e}"
#   end
#   
# end
# 
# @pacs.keys.sort{|a,b| a.casecmp(b)}.each do |k|
#   if @pacs[k][:desc]
#     # toplevel category
#     puts "#{k}: #{@pacs[k][:desc]}"
#   else
#     @pacs[k].keys.sort{|a,b| a.casecmp(b)}.each do |sk|
#       if @pacs[k][sk][:desc]
#         puts "\t#{k}.#{sk}: #{@pacs[k][sk][:desc]}"
#       else
#         @pacs[k][sk].keys.sort{|a,b| a.casecmp(b)}.each do |ssk|
#           puts "\t\t#{k}.#{sk}.#{ssk}: #{@pacs[k][sk][ssk][:desc]}"
#         end
#       end
#     end
#   end
# end
