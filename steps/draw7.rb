#
# ---------------------------------------------------------
# Draw7 is search Level7 layer control field.
# create  : 2017/12/02 
# version : 0.1 create
#  
# usage: $ ruby draw7.rb drwA.csv
# option
# -v      : verbose logs
# 
# ファイルを指定すると、手順のステップごとにdrawtoolsの
# jsonファイルを作成します
# 

require 'csv'
require "date"

# -------------------------------------------
# Configuration options 
# -------------------------------------------

class Config
  attr_accessor :color
  attr_accessor :verbose
  attr_accessor :splitfiles
  
  def initialize
    @color = "dodgerblue"
    @verbose = true
    @splitfiles = false
  end

  def set_mode(argv)
    argv.each do |arg|
      case arg
        when "-s" then @splitfiles = true
        when "-v" then @verbose = true
      end
    end
  end
  # verbose print method
  def vprint(mode,arg)
    if @verbose  == true then
      print arg
    end
  end 
end

#
# link の出力関数
#
def print_links(link_data,outfile=STDOUT)
  #  IITC Drawtools link 
  # ",{\"type\":\"polyline\",\"latLngs\":[{\"lat\":36.571202,\"lng\":136.629249},{\"lat\":36.585676,\"lng\":136.679618}],\"color\":\"dodgerblue\"}\n"
  linkBEGIN = "[\n"
  linkA = "{\"type\":\"polyline\",\"latLngs\":[{\"lat\":"
  linkB = ",\"lng\":"
  linkC = "},{\"lat\":"
  linkD = ",\"lng\":"
  linkE = "}],\"color\":\"dodgerblue\"}\n"
  linkEND ="]\n"

  File.open(outfile,"w") do |io|
    io.print linkBEGIN 
    link_data.each_with_index do |link,i|
      if i != 0 then  # 先頭以外はカンマをつける
        io.print ","
      else
        io.print " "
      end
      io.print  linkA + "#{link[3]}" + linkB + "#{link[2]}" + linkC + "#{link[6]}" +  linkD + "#{link[5]}" + linkE
    end
    io.print linkEND 
  end
end

#
# １～最終セクションまで段階的に出力する
#
def print_sections(section_link, last_section)

  (1..last_section).each do |i| #セクション番号で選択する
    STDOUT.puts  "======== #{i} ========"
    w = section_link.select {|row| row[0] <= i }
    print_links(w,"#{ARGV[0]}_step#{format("%02d", i)}.txt")
  end
end

# ======================================================
# Main
# =====================================================

# time
STDERR.print "[#{Time.now.strftime("%Y/%m/%d %X")}] start\n"
conf = Config.new
conf.set_mode(ARGV)

all_section =[]
section_link = []
section = 0
last_section = 0

#　CSVを取り込む
CSV.foreach(ARGV[0], encoding: "UTF-8:UTF-8") do |row|
  if row[0].nil? && row[1].nil? then
    section += 1
  else
    row.unshift(section)
    section_link.push(row) 
    last_section = section
  end
end

print_sections(section_link,last_section)

STDERR.print "[#{Time.now.strftime("%Y/%m/%d %X")}]   end\n"

