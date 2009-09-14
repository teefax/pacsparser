#!/usr/bin/env ruby -wKU
# 
# parse PACS2008 file and do things with it
require 'open-uri'
require "strscan"
require 'yaml'

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
      # sort, so that the ids are in the right order
      @lines.sort{|a,b| a.casecmp(b)}.to_s
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
      raise
    end
  end
  
  def print
    # puts @container.to_yaml
    @container.each do |i|
      print_pacs(i) if !i.nil?
    end
  end
  
  def print_pacs(pacs, indent = "")
    puts "#{indent}#{pacs.id} #{pacs.desc}"
    if !pacs.children.nil?
      pacs.children.keys.sort{ |a,b| a.to_s.casecmp(b.to_s) }.each do |k|
        print_pacs(pacs.children[k], indent+"\t") if !pacs.children[k].nil?
      end
    end
  end
  
  private
  
  def parse_content
    parse_pacs or
    parse_comment or
    ignore
  end
  
  def parse_pacs
    # FIXME: this really should be split into subroutines - but I couldn't care less ATM
    if @input.scan(/(\d{2})\.(\d{2}).(..) (.*)\n/)
      current_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
      desc = @input[4]
      
      if @input[1].to_i % 10 == 0
        # top-level elements
        @container.push PACS.new(current_id, desc)
      elsif @input[2] == '00'
        # second level categories
        parent = @container[@input[1].to_i/10.round]
        parent.children ||= {}
        parent.children[@input[1].to_i] =  PACS.new(current_id, desc)
      else
        # third level and below
        if @input[1] == '99'
          # special handling for errata group (why is this a subgroup?!?? WTF?)
          @container[9] = PACS.new(current_id, desc) if @container[9].nil?
          @container[9][:children] ||= {}
          @container[9][:children][@input[1].to_i] ||= PACS.new()
        end

        parent = @container[@input[1].to_i/10.round][:children][@input[1].to_i]
        parent.children ||= {}
        parent.children[current_id] =  PACS.new(current_id, desc)
        
        if @input[3].start_with?("-")
          # start of level 4 group - scan ahead for level 3 ids with uppercase first characters
          while !@input.eos? and @input.scan(/(\d{2})\.(\d{2}).([A-Z].) (.*)\n/)
            l4_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
            l4_desc = @input[4]
            
            parent.children[current_id].children ||= {}
            parent.children[current_id].children[l4_id] = PACS.new(l4_id, l4_desc)
            
            if @input[3].end_with?("-")
              # start of a level 5 group
              while !@input.eos? and @input.scan(/(\d{2})\.(\d{2}).([a-z].) (.*)\n/)
                l5_id = "#{@input[1]}.#{@input[2]}.#{@input[3]}"
                l5_desc = @input[4]
                
                parent.children[current_id].children[l4_id].children ||= {}
                parent.children[current_id].children[l4_id].children[l5_id] = PACS.new(l5_id, l5_desc)
              end
            end
          end
        end
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
