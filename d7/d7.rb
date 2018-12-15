#!/usr/bin/env ruby
# coding: utf-8
require 'csv'
require 'logger'
require 'matrix'
require 'io/console/size'
require 'optparse'

# ===============================================================
#  new D7.rb  program 2018-03-23 v2.0.0
# ===============================================================
# changelog
# 20180322 CSV入力ファイルにヘッダを不要とした（iso互換）
# 20180322 portalクラスに連番(portalnumber)を付与した
# 20180322 -aオプションで最外周を含めて複数の探索を行うように修正
# 20180322 logの改修によりカレントディレクトリに標準的なログが出力される
# 20180324 ２重のループを１重に見直して高速化
# ===============================================================
#  ** Todo ** 
# ポータルの出力順序をisoさん互換にする:未定
# リンクの色を切り替えられるようにする
# ファイルの出力を分割する
# ===============================================================

# -------------------------------------------
# Logger setup / global scope
# -------------------------------------------
$log = Logger.new('d7.log')
$stdout.sync = true #書いておかないと出力がバッファに溜め込まれるかも

# -------------------------------------------
# Configuration options 
# -------------------------------------------
class Config
  attr_accessor :imperfect_search
  attr_accessor :layer
  attr_accessor :verbose
  attr_accessor :triangle
  attr_accessor :scale
  attr_accessor :color
  attr_accessor :allrange

  def initialize
    @imperfect_search = true
    @all_range_search = false
    @layer = 7
    @verbose = false
    @triangle = "y"
    @scale = 10
    @color = "dodgerblue"
    @allrange = false
  end

  def set_mode(argv)
    $log.info("argument = #{argv}")
    OptionParser.new do |opt|
      #opt.on('-t','頂点指定検索(デフォルト)') {|v| @triangle = true}
      opt.on('-t [MODE]', 'y:頂点指定する(デフォルト) n:頂点指定しない'){|v| @triangle = v || "y"  }
      opt.on('-i','全多重探索　(デフォルト)') {|v| @imperfect_search = true}
      opt.on('-p','完全多重探索')            {|v| @imperfect_search = false}
      opt.on('-7','全７探索　　(デフォルト)')  {|v| @layer = 7}
      opt.on('-6','全６探索')             {|v| @layer = 6}
      opt.on('-5','全５探索')             {|v| @layer = 5}
      opt.on('-4','全４探索')             {|v| @layer = 4}
      opt.on('-3','全３探索')             {|v| @layer = 3}
      opt.on('-a','全域検索')             {|v| @allrange = true}
      opt.on('-c [HTML_COLOR_CODE]', 'Link色を指定（省略：dodgerblue）'){|v| @color = v || "dodgerblue"}
      opt.on('-v','メッセージ表示')        {|v| @verbose = true}
      #opt.on('-b VALUE',   '1文字オプション 引数あり（必須）')   {|v| option[:b] = v}
      #opt.on('-c [VALUE]', '1文字オプション 引数あり（省略可能）'){|v| option[:c] = v
      opt.parse!(ARGV)
    end
  end
end

# -------------------------------------------
# CSV file reader / portallist -> area object
# -------------------------------------------
class Loader
  def load(portallist)
    area = Area.new
    CSV.read(portallist, encoding: "UTF-8:UTF-8",\
     header_converters: nil,headers: false, skip_blanks: true).each do |row|
        wk =  Portal.new(row[0].to_f,row[1].to_f,row[2] )   # CSV→portal作成
        area.push( wk )
    end                                   
    return area
  end
end


# -------------------------------------------
# Area Portals correction
# -------------------------------------------
class Area
  attr_reader :array
  def initialize
    @array = Array.new   # インスタンス変数で配列を作る
  end
  # 配列の数
  def length
    return self.array.length
  end
  # 配列のdrop
  def drop(num)
    return self.array.drop(num)
  end
  # 配列に追加
  def push(portal)
    self.array.push(portal) 
  end
  # データ取得
  def pop
    self.array.pop 
  end
  def print
    @array.each_with_index do |row,i|
      STDERR.puts "#{row.print}"
    end
  end
end
# -------------------------------------------
# Portal Class
# -------------------------------------------
class Portal
  attr_reader :long,:lat,:portalname,:portalnumber   # 設定値
  @@portalnumber = 0       # ポータル番号（クラス変数）
  def initialize(long,lat,portalname)
    @long = long
    @lat = lat
    @portalname = portalname
    @portalnumber = getNumber()
  end
  # 読み込んだ順にポータル番号を割り当てる
  def getNumber
    @@portalnumber = @@portalnumber + 1
    return @@portalnumber
  end
  #　設定値をVectorで取り出す
  def vector 
    return  Vector[self.long ,self.lat,0]
  end

  # 設定値を文字列で出力します（No,ポータル名,経度,緯度）
  def print 
    return "#{self.portalnumber},#{self.portalname},#{self.long},#{self.lat}"
  end
end
# -------------------------------------------
# MultipleControlField Class 
# -------------------------------------------
class MultipleControlField
  attr_accessor :a,:b,:c,:x,:parent,:child
  @@counter = 0 
    # △abc xは多重CFの中心ポータル
  def initialize(a,b,c,x)
    # portals 
    @a = a; @b = b; @c = c; @x =x
    @child = Array.new
    @visited_flag = false
  end
  # 自分の親CF
  def set_parent(parent)
    @parent = parent
  end
  # 自分の子CF
  def set_child(child)
   @child.push(child)
  end
  # 自分の子CF
  def get_child
     if child.length > 0 then
      return @child.pop
    end 
  end
  # 配下のChildをすべて消す
  def remove_child
    if @child.length > 0 then
      @child = []  
      return true
    end
  end
  #下位のCFの数
  def length
    return @child.length
  end

  #debug print
  def portallist
    # Portal information
    if @x != nil then           # 先頭でなければ
      print  "#{@x.long},#{@x.lat},\"#{utf2sjis(@x.portalname)}\"\n"
      @@counter += 1
    else                        # 先頭の場合（見出しと外郭）
      print "\nlong,\tlat,\tportalname\n"
      print  "#{@a.long},#{@a.lat},\"#{utf2sjis(@a.portalname)}\"\n"
      print  "#{@b.long},#{@b.lat},\"#{utf2sjis(@b.portalname)}\"\n"
      print  "#{@c.long},#{@c.lat},\"#{utf2sjis(@c.portalname)}\"\n"
      @@counter += 3
    end
    # 下位のポータルを出力
    @child.each_with_index do | portal,i|
      portal.portallist
    end
  end

  def linklist
    #  IITC Drawtools link 
    # ",{\"type\":\"polyline\",\"latLngs\":[{\"lat\":36.571202,\"lng\":136.629249},{\"lat\":36.585676,\"lng\":136.679618}],\"color\":\"dodgerblue\"}\n"
    linkBEGIN = "["
    linkA = "{\"type\":\"polyline\",\"latLngs\":[{\"lat\":"
    linkB = ",\"lng\":"
    linkC = "},{\"lat\":"
    linkD = ",\"lng\":"
    linkE = "}],\"color\":\"#{$conf.color}\"}\n"
    linkEND ="]"
    # Link information
    if @x == nil then
      # 最外周ならば△abcのリンクを描く
      print       linkA + "#{@a.lat}" + linkB + "#{@a.long}" + linkC + "#{b.lat}" +  linkD +"#{b.long}" + linkE
      print "," + linkA + "#{@b.lat}" + linkB + "#{@b.long}" + linkC + "#{c.lat}" +  linkD +"#{c.long}" + linkE
      print "," + linkA + "#{@c.lat}" + linkB + "#{@c.long}" + linkC + "#{a.lat}" +  linkD +"#{a.long}" + linkE
    else
      # 内側なら中心と△abcとのリンクを描く
      print "," + linkA + "#{@x.lat}" + linkB + "#{@x.long}" + linkC + "#{a.lat}" +  linkD +"#{a.long}" + linkE
      print "," + linkA + "#{@x.lat}" + linkB + "#{@x.long}" + linkC + "#{b.lat}" +  linkD +"#{b.long}" + linkE
      print "," + linkA + "#{@x.lat}" + linkB + "#{@x.long}" + linkC + "#{c.lat}" +  linkD +"#{c.long}" + linkE
    end
    # 下位のリンクを出力
    @child.each_with_index do | portal,i|
      portal.linklist
    end
  end
end
# -------------------------------------------
#  △ABCに含まれるポータルを抽出する
# -------------------------------------------
class Triangle
  attr_accessor :a, :b, :c    #対象とする三角形の頂点
  attr_accessor :ab,:bc,:ca　 #各辺のベクトル a->b->c->a ...
  #範囲の頂点を設定する a,b,cはPodtalクラス
  def set_point(a, b, c)
    @a = a.vector; @b = b.vector;  @c = c.vector
    # 三角形の各辺のベクトル（a->b->c->a）
    @ab = @b - @a
    @bc = @c - @b
    @ca = @a - @c
  end
  # 三角形と点の当たり判定(△ABCの中か外か？)
  # 戻り値 True:三角形の内側に点がある/ False:三角形の外側に点がある
  def is_inside(px)
    #外積の算出
    z1 = @ab.cross_product( px - @a )
    z2 = @bc.cross_product( px - @b )
    z3 = @ca.cross_product( px - @c )
    # 三角形の内側にある 外積が全て同じ方向（全部＋または全部ー）
    if     (z1[2] > 0 and  z2[2] > 0 and  z3[2] > 0 ) \
       ||  (z1[2] < 0 and  z2[2] < 0 and  z3[2] < 0 ) then
      return true  # 内側にある
    else
      return false # 内側にない
    end
  end
  # 渡したエリアを三角形でフィルタして新しいエリアを作る(デフォルトの探索は内心に近い順で)
  def filter( area ,mode = :ic )
    wk = Area.new     # 空のポータルリストを作る
    area.array.each_with_index do |portal,i|
      if is_inside(portal.vector) then
        wk.push(portal)
      end
    end
    if mode == :ic then     # 内心と各ポータルの距離を基準にソートする
      wk.array.sort_by!{ |portal| distance( inner_center , portal.vector )}
    end
    if mode == :gc then     # 重心と各ポータルの距離を基準にソートする
      wk.array.sort_by!{ |portal| distance( gravity_center , portal.vector )}
    end
    return wk  
  end
  # 渡したエリアを三角形でフィルタして新しいエリアを作る
  def Trianglefilter( area,a,b,c )
    self.set_point(a,b,c)
    return self.filter(area)
  end
  # 2点間のベクトル間の距離を測る
  def distance( a ,b )
    #STDERR.print ("distance = #{(b - a).r}\n")
    return (b - a).r.abs
  end
  # 3角形の内心を調べる
  # http://examist.jp/mathematics/planar-vector/naisin-vector/
  def inner_center( a = @a, b = @b ,c=@c )
    return @ic == nil ? @ic = (a * a.r + b * b.r + c * c.r )/(a.r + b.r + c.r) : @ic
  end
  # 3角形の重心を調べる
  def gravity_center( a = @a, b = @b ,c=@c )
    return @gc == nil ? @gc = (a + b + c) / 3 : @gc
  end
  # print area portal
  def print
    return a,b,c
  end
end
# ======================================================
# New CF Search Finder
# =====================================================
class Finder
  attr_accessor :layer
  attr_accessor :triangle

  @@counter = 0               # Search呼び出し件数
  OUTLINE_PORTALS = 3;        # 外周ポータル数
  @triangle         = true    # 三角検索
  @@negative_cache = Hash.new # 対象外のキャッシュ
  @@cache_hits_counter = 0    # キャッシュに合致した回数
  #      Array       0  1  2   3   4    5    6
  #      layer       1  2  3   4   5    6    7
  INSIDE_PORTALS = [ 0, 1, 4, 13, 40, 121, 364, ] # OUTSIDE_PORTAL+INSIDE_PORTALですべて
  LAYER_PORTALS  = [ 0, 1, 3,  9, 27,  81, 273, ]
  # 検索対象レイヤ
  def initialize( layer = 7 )
      @layer = layer
  end
  # 検索
  def search(area,a,b,c,cf,level="")
    @@counter += 1
    #△abcの3点は最下層のCF
    if @layer == 1  then  return true end 
    # すでに@layerは見つからないとキャッシュに記録されている
    if check_negative(a,b,c) then 
      return false 
    end

    # 一階層下の中心ポータルの候補を探す
    minimum_portals = INSIDE_PORTALS[ @layer - 2 ]      #最小値は内部のポータル数
    if $conf.imperfect_search then
      maximum_portals = 100000                            #完全多重の場合は範囲設定する
    else
      maximum_portals = minimum_portals                   #完全多重の場合は定数値
    end
    t = Triangle.new

    # 対象のエリアを確認する
    area.array.each_with_index do |x,i|
      # 対象範囲のエリアでポータルの絞り込みを行う
      xAB_area = t.Trianglefilter(area,a,b,x) 
      xBC_area = t.Trianglefilter(area,b,c,x) 
      xCA_area = t.Trianglefilter(area,c,a,x) 

      x1 = xAB_area.length    #△abx
      x2 = xBC_area.length    #△bcx
      x3 = xCA_area.length    #△cax

      if    x1 >= minimum_portals and x1 <= maximum_portals \
        and x2 >= minimum_portals and x2 <= maximum_portals \
        and x3 >= minimum_portals and x3 <= maximum_portals then
        # xは候補になると判定
        candidate_print(a,b,c)
        # リンクプランに登録するCFを作成する
        child = MultipleControlField.new(a,b,c,x)
        # 再帰で下位を調べる
        f = Finder.new( @layer - 1 ) 
        if    f.search(xAB_area,a,b,x,child,"a") \
          and f.search(xBC_area,b,c,x,child,"b") \
          and f.search(xCA_area,c,a,x,child,"c") then
          #　探索されたCFを親と関連付ける
          child.set_parent(cf)
          cf.set_child(child)
          return true
        else
          set_negative(a,b,c)
        end
      else 
        set_negative(a,b,c)
      end
      #progress_bar( 7 - @layer , 7 )
      #puts
    end
    return false
  end
  
  # 対象の組み合わせが既に検索失敗しているかどうかを調べる
  def check_negative(a,b,c)
    if @@negative_cache["[@layer]#{a.portalnumber},#{b.portalnumber},#{c.portalnumber}"] then  
      return false 
    end
  end
  # 対象の組み合わせが検索失敗したことを記録する
  def set_negative(a,b,c)
    @@negative_cache["[@layer]#{a.portalnumber},#{b.portalnumber},#{c.portalnumber}"] = true
  end
  #　候補の組み合わせを表示する
  def candidate_print(a,b,c)
    if $conf.verbose then    # 冗長表示の指定のある場合のみ
      debug_time = "[#{Time.now.strftime("%Y/%m/%d %X")}] " 
      debug_text = " "*(7 - layer)  + "candidate #{layer}  #{utf2sjis(a.portalname)}, #{utf2sjis(b.portalname)}, #{utf2sjis(c.portalname)}"
      STDERR.print debug_time +  debug_text +"\n"
      $log.debug(debug_text)
    end
  end

  #　--------------------------------------------
  # print
  #　--------------------------------------------
  def portallist
    # Portal information
    STDERR.print "--------------------------------------\n"
    STDERR.print  "#{a.long},#{a.lat},#{a.portalname}\n"
    STDERR.print  "#{b.long},#{b.lat},#{b.portalname}\n"
    STDERR.print  "#{c.long},#{c.lat},#{c.portalname}\n"
    if x != nil then
      STDERR.print  "#{x.long},#{x.lat},#{x.portalname}\n"
    end
    # Link information
    if x == nil then
      # 最外周ならば△abcのリンクを描く
      STDERR.print  "#{a.portalname}-#{b.portalname},#{a.long},#{a.lat},#{b.long},#{b.lat}\n"
      STDERR.print  "#{b.portalname}-#{c.portalname},#{b.long},#{a.lat},#{c.long},#{c.lat}\n"
      STDERR.print  "#{c.portalname}-#{a.portalname},#{c.long},#{a.lat},#{a.long},#{a.lat}\n"       
    else
      # 内側なら中心と△abcとのリンクを描く
      STDERR.print  "#{x.portalname}-#{a.portalname},#{x.long},#{x.lat},#{a.long},#{a.lat}\n"
      STDERR.print  "#{x.portalname}-#{b.portalname},#{x.long},#{x.lat},#{b.long},#{b.lat}\n"
      STDERR.print  "#{x.portalname}-#{c.portalname},#{x.long},#{x.lat},#{c.long},#{c.lat}\n"
    end
  end
end

# ------------------------------------------------------------------------
# utility method
# ------------------------------------------------------------------------
# UTF-8 -> Shift_JIS
def utf2sjis(str)
  return str
  #return str.encode("Shift_JIS","UTF-8",:undef => :replace, :invalid => :replace,:replace => "*")
end
# Shift_JIS -> UTF-8
def sjis2utf(str)
  return str.encode("UTF-8","Shift_JIS",:undef => :replace, :invalid => :replace,:replace => "*")
end
# 指定した基準点からの距離でソートする
def sort_portals( portals,reference_point)
  wk = portals.array.sort_by!{ |portal| 
      ( reference_point.vector - portal.vector ).r.abs # 2点間のベクトル間の距離を測る
  }
  return wk
end
# -------------------------------------------
# progress_bar
# -------------------------------------------
def progress_bar(i, max = 100)
  i = max if i > max
  rest_size = 1 + 5 + 1      # space + progress_num + %
  bar_width = 79 - rest_size # (width - 1) - rest_size = 72
  percent = i * 100.0 / max
  bar_length = i * bar_width.to_f / max
  bar_str = ('#' * bar_length).ljust(bar_width)
#  bar_str = '%-*s' % [bar_width, ('#' * bar_length)]
  progress_num = '%3.1f' % percent
  print "\r#{bar_str} #{'%5s' % progress_num}%"
end
# -------------------------------------------
# 数値の３桁区切り（integer)
# -------------------------------------------
class Integer
  def jpy_comma
    self.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
  end
end
# ------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------

$log.info("start")
# configuration
$conf = Config.new
$conf.set_mode(ARGV)

#load CSV portal list
loader = Loader.new
area = loader.load(ARGV[0])

# 探索対象の頂点の設定
a = area.array[0]
b = area.array[1]
c = area.array[2]
cf = MultipleControlField.new(a,b,c,nil)
# 指定の深さを指定
f = Finder.new($conf.layer)
# 三角形探索の準備
t = Triangle.new

# 探索
if $conf.triangle == "y" then #　(-t指定)

  # 全域検索ではない(３頂点を指定した単独検索)
  if !$conf.allrange then
    target = t.Trianglefilter(area,a,b,c)
    if f.search(target,a,b,c,cf) then
      print "\n=== Portal list ===\n"
      cf.portallist
      print "\n=== Link list ===\n"
      print "[\n"
      cf.linklist
      print "]\n"
      $log.info("L#{$conf.layer} HCF ( #{a.portalname} | #{b.portalname} | #{c.portalname} )")
    else
      $log.info("sorry, not found")
      return false
    end

  else #三角の範囲での総当り検索(-t -a )

    search_area = t.Trianglefilter(area,a,b,c)
    search_area.push(a);  search_area.push(b);  search_area.push(c) #最外周も含める
    
    #検索範囲を外側からに設定する(大きい△から探すことになる)
    aside = sort_portals( search_area,a ).take(100)
    bside = sort_portals( search_area,b ).take(100)
    cside = sort_portals( search_area,c ).take(100)
    # a/b/cの３つの組合せ
    selected_area = aside.product( bside,cside ) 
    max_combination = selected_area.length
    STDERR.print "[Layer#{$conf.layer} outside ] #{selected_area.length} "
    STDERR.print "\t#{a.portalname},#{b.portalname},#{c.portalname}\n"

    i = 0
    found_count = 0
    selected_area.collect do |set|
      cf = MultipleControlField.new(set[0],set[1],set[2],nil)
      target = t.Trianglefilter(search_area,set[0],set[1],set[2])
      if f.search(target,set[0],set[1],set[2],cf) then
        found_count = found_count + 1
        print "\n=== Portal list [#{found_count}] ===\n"
        cf.portallist
        print "\n=== Link list [#{found_count}] ===\n"
        print "[\n"
        cf.linklist
        print "]\n"
        $log.info("L#{$conf.layer} HCF [#{found_count}] ( #{set[0].portalname} | #{set[1].portalname} | #{set[2].portalname} )")
      end

      if $conf.verbose then    # 冗長表示の指定のある場合のみ
        puts("count = #{i+1}/#{max_combination.jpy_comma}  CF = #{found_count}  ( #{i+1} : #{set[0].portalname} | #{set[1].portalname} | #{set[2].portalname} )")
      end

      if found_count  >= 32 or i >= 1000 then #見つけたCFか、処理件数が規定件数を超えたら終了する
        break 
      end
      i = i + 1
    end

  end

else # 単純全域検索 (-a -t n )
  search_area = area  
  # a/b/cの３つの組合せ
  selected_area = search_area.array.combination(3) 
  max_combination = search_area.length
  STDERR.print "== 単純全域探索 == \n"
  STDERR.print "[Layer#{$conf.layer} outside ] #{max_combination} \n"
  i = 0
  found_count = 0
  selected_area.collect do |set|
    cf = MultipleControlField.new(set[0],set[1],set[2],nil)
    target = t.Trianglefilter(search_area,set[0],set[1],set[2])
    if f.search(target,set[0],set[1],set[2],cf) then
      found_count = found_count + 1
      print "\n=== Portal list [#{found_count}] ===\n"
      cf.portallist
      print "\n=== Link list [#{found_count}] ===\n"
      print "[\n"
      cf.linklist
      print "]\n"
      $log.info("L#{$conf.layer} HCF [#{found_count}] ( #{set[0].portalname} | #{set[1].portalname} | #{set[2].portalname} )")
    end

    if $conf.verbose then    # 冗長表示の指定のある場合のみ
      puts("count = #{i+1}/#{max_combination.jpy_comma}  CF = #{found_count}  ( #{i+1} : #{set[0].portalname} | #{set[1].portalname} | #{set[2].portalname} )")
    end

    if found_count  >= 32  then # 見つけたCFが規定件数を超えたら終了する
      break 
    end
    i = i + 1
  end

end
$log.info("finished")