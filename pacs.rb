#!/usr/bin/env ruby -wKU
# 
# parse PACS2008 file and do things with it
# 
# Author: Eike Bernhardt <bernhardt@isn-oldenburg.de>
# 
# (c) Copyright 2009 ISN Oldenburg http://www.isn-oldenburg.de/
# 
# Released under the MIT License - see LICENSE
# 
require 'open-uri'
require "strscan"

# PACSFILE = "http://www.aip.org/pacs/pacs08/ASCII2008FullPacs.txt"
PACSFILE = "ASCII2008FullPacs.txt"

MODE="ruby" # see print()

class PACSParser
  PACS = Struct.new(:id, :desc, :children, :comment)

  attr_reader :container
  
  def initialize
    @container = Array.new
    @current = @parent = nil
  end
  
  def load
    begin
      f = File.open(PACSFILE,'r')
      @lines = f.read
      f.close
      # sort, so that the ids are in the right order
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
        parse_toplevel ||
        parse_secondlevel ||
        parse_thirdlevel ||
        parse_fourthlevel ||
        parse_fifthlevel ||
        parse_comment ||
        ignore
      end
    rescue Exception => e
      # pp @container
      puts "Error in line: "+@input[0]
      raise
    end
  end
  
  def print
    @container.each do |i|
      if MODE == "ruby"
        print_ruby(i) if !i.nil?
      else
        print_pacs(i) if !i.nil?
      end
    end
  end
  
  def print_pacs(pacs, indent = "")
    puts "#{indent}#{pacs.id} #{pacs.desc}"
    if !pacs.comment.nil?
      pacs.comment.each do |c|
        puts "#{indent} ... ... #{c}"
      end
    end
    if !pacs.children.nil?
      pacs.children.keys.sort{ |a,b| a.to_s.casecmp(b.to_s) }.each do |k|
        print_pacs(pacs.children[k], indent+"\t") if !pacs.children[k].nil?
      end
    end
  end
  
  def print_ruby(pacs, parent = nil)
    puts "Pacs.create!(:pid => '#{pacs.id}', :desc => '#{pacs.desc.gsub(/'/, "\\\\'")}', :comment => '#{pacs.comment.nil? ? '' : pacs.comment.join("\n")}', :parent => #{parent.nil? ? 'nil' : "Pacs.find_by_pid('#{parent}')"})"
    if !pacs.children.nil?
      pacs.children.keys.sort{ |a,b| a.to_s.casecmp(b.to_s) }.each do |k|
        print_ruby(pacs.children[k], pacs.id) if !pacs.children[k].nil?
      end
    end
  end
  
  private
  
  def parse_toplevel
    if @input.scan(/(\d0)\.(\d{2})\.(..) (.*)\n/)
      @current_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
      @desc = @input[4]
      @container.push( PACS.new(@current_id, @desc, {}) )
      @current = @container.last
    else
      false
    end
  end
  
  def parse_secondlevel
    if @input.scan(/(\d{2})\.(00)\.(..) (.*)\n/)
      @current_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
      @desc = @input[4]
      @parent = @container[@input[1].to_i/10.round]
      @current = @parent.children[@current_id] = PACS.new(@current_id, @desc, {})
    else
      false
    end
  end

  def parse_thirdlevel
    if @input.scan(/(\d{2})\.(\d{2})\.(\+.) (.*)\n/) # normal 3rd level, just add
      @current_3rd_lv = @current_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
      @desc = @input[4]
      # this might end a subgroup. so re-set parent
      @parent = @container[@input[1].to_i/10.round].children["#{@input[1]}.00.00"]
      @current = @parent.children[@current_id] = PACS.new(@current_id, @desc, {})
    elsif @input.scan(/(\d{2})\.(\d{2})\.(\-.) (.*)\n/) # opening of 4th level group
      @current_3rd_lv = @current_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
      @desc = @input[4]

      # errata group
      if @input[1] == '99' and @container[9].children['99.00.00'].nil?
        @container[9].children['99.00.00'] = PACS.new('','', {})
      end

      # this might end a subgroup. so re-set parent
      @parent = @container[@input[1].to_i/10.round].children["#{@input[1]}.00.00"]
      @current = @parent = @parent.children[@current_id] = PACS.new(@current_id, @desc, {})
    else
      false
    end
  end
  
  def parse_fourthlevel
    if @input.scan(/(\d{2})\.(\d{2})\.([A-Z][^-]) (.*)\n/) # normal 4th level, just add
      @current_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
      @desc = @input[4]
      # this resets parent to level 4
      @parent = @container[@input[1].to_i/10.round].children["#{@input[1]}.00.00"].children[@current_3rd_lv]
      
      @current = @parent.children[@current_id] = PACS.new(@current_id, @desc, {})
    elsif @input.scan(/(\d{2})\.(\d{2})\.([A-Z]\-) (.*)\n/) # opening of 5th level group
      @current_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
      @desc = @input[4]
      # this resets parent to level 4
      @parent = @container[@input[1].to_i/10.round].children["#{@input[1]}.00.00"].children[@current_3rd_lv]
      
      @current = @parent = @parent.children[@current_id] = PACS.new(@current_id, @desc, {})
    else
      false
    end
  end

  def parse_fifthlevel
    if @input.scan(/(\d{2})\.(\d{2})\.([a-z][a-z]) (.*)\n/) # normal 5th level, just add
      @current_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
      @desc = @input[4]
      @current = @parent.children[@current_id] = PACS.new(@current_id, @desc, {})
    else
      false
    end
  end
    
  def parse_comment
    if @input.scan(/\.\.\. \.\.\. (.*)\n/)
      # found a comment, append this to @current element
      comment = @input[1]
      @current.comment ||= []
      @current.comment.push comment
    else
      false
    end
  end
  
  def ignore
    if !@input.check(/..\...\... .*\n/) and !@input.check(/ \.{3} \.{3} .*\n/) and @input.scan(/(.*)\n/)
      STDERR.puts "Ignoring '#{@input[1]}'"
    else
      false
    end
  end
  
  def trim_space
    @input.scan(/\s+/)
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
# puts p.container.to_yaml
