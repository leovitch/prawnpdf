# coding: UTF-8


require 'test/unit'

# Get PrawnPDF
require File.dirname(__FILE__) + '/../lib/prawnpdf'

require 'rubygems'
require 'prawn'
require 'prawn/measurement_extensions'
require 'prawn/core'
Prawn.debug = true

class TestPPDF < PrawnPDF::PPDF
  # To match the output of the FPDF tutorials closely you need
  # to use Arial like they do.
  # Unfortunately, that would make this test non-portable since
  # Arial is not a redistributable font.
  # To make these tests portable, use_arial defaults to false and
  # Helvetica is used instead (but the output looks slightly
  # different from the FPDF tests).
  # If you have a copy of Arial available and you want to match
  # the original tests more closely, edit the paths listed
  # below to find your copies of Arial and set the default
  # for use_arial to true.
  def initialize(orientation='P',unit='mm',format='A4',use_arial=false)
    super(orientation,unit,format)
    @use_arial = use_arial
    if @use_arial
      AddFontFamily('Arial','/Library/Fonts/Arial.ttf',
              '/Library/Fonts/Arial Bold.ttf',
              '/Library/Fonts/Arial Italic.ttf',
              '/Library/Fonts/Arial Bold Italic.ttf')
    end
  end
  
  def SetFont(family,style=nil,size=nil)
    if (!@use_arial) and family == 'Arial'
      family = 'Helvetica'
    end
    super(family,style,size)
  end
  
end

class PrawnPDFTest < Test::Unit::TestCase

  def initialize(*args)
    super(*args)
    @output_dir = File.join(File.dirname(__FILE__),'test_output')
    if ! File.directory? @output_dir
      Dir.mkdir @output_dir
    end
  end
  
  # ------------------------------------------------------------------
  def test_tutorial1
    puts "-------------- Starting Tutorial 1 --------------"
    @pdf = TestPPDF.new
    @pdf.AddPage
    @pdf.SetFont('Arial','B',16)
    @pdf.Cell(40,10,'Hello World!',1)
    @pdf.Output(File.join(@output_dir,'tutorial1.pdf'))
    puts "-------------- Finished Tutorial 1 --------------"
  end
  
  # ------------------------------------------------------------------
  class Tutorial2_PPDF < TestPPDF
    def Header
      # Logo
      Image('logo_pb.png',10,8,33)
      # Arial bold 15
      SetFont('Arial','B',15)
      # Move to the right
      Cell(80)
      # Title
      Cell(30,10,'Title',0,0,'C')
      # Line break
      Ln(20)
    end

    def Footer
      # Position at 1.5 cm from bottom
      SetY(-15)
      # Arial italic 8
      SetFont('Arial','I',8)
      # Page number
      Cell(0,10,"Page #{self.PageNo}/{nb}",0,0,"C")
    end
  end
  
  def test_tutorial2
    puts "-------------- Starting Tutorial 2 --------------"
    @pdf = Tutorial2_PPDF.new
    @pdf.AliasNbPages()
    @pdf.AddPage()
    @pdf.SetFont('Times','',12)
    (1..40).each do |i|
      @pdf.Cell(0,10,"Printing line number #{i}",0,1)
    end
    @pdf.Output(File.join(@output_dir,'tutorial2.pdf'))
    puts "-------------- Finished Tutorial 2 --------------"
  end
  
  # ------------------------------------------------------------------
  class Tutorial3_PPDF < TestPPDF
    attr_accessor :title
    
    def Header
      # Arial bold 15
      SetFont('Arial','B',15)
      # Calculate width of title and position
      w=GetStringWidth(@title)+6
      SetX((210-w)/2)
      # Colors of frame, background and text
      SetDrawColor(0,80,180)
      SetFillColor(230,230,0)
      SetTextColor(220,50,50)
      # Thickness of frame (1 mm)
      SetLineWidth(1)
      # Title
      Cell(w,9,@title,1,1,'C',true)
      # Line break
      Ln(10)
    end
    def Footer
      # Position at 1.5 cm from bottom
      SetY(-15)
      # Arial italic 8
      SetFont('Arial','I',8)
      # Text color in gray
      SetTextColor(128)
      # Page number
      Cell(0,10,"Page #{self.PageNo}",0,0,'C')
    end
    def ChapterTitle(num,label)
      # Arial 12
      SetFont('Arial','',12)
      # Background color
      SetFillColor(200,220,255)
      # Title
      Cell(0,6,"Chapter #{num} : #{label}",0,1,'L',true)
      # Line break
      Ln(4)
    end
    def ChapterBody(file)
      # Read text file
      mode = "r"
      # Binary if on Windows
      if Config::CONFIG['host_os'] =~ /msinw|mingw/
        mode += "b"
      end
      f=File.new(file,mode)
      txt=f.read
      f.close
      # Times 12
      SetFont('Times','',12)
      # Output justified text
      MultiCell(0,5,txt)
      # Line break
      Ln()
      # Mention in italics
      SetFont('','I')
      Cell(0,5,'(end of excerpt)')
    end
    def PrintChapter(num,title,file)
      AddPage()
      ChapterTitle(num,title)
      ChapterBody(file)
    end
  end
  
  def test_tutorial3
    puts "-------------- Starting Tutorial 3 --------------"
    @pdf = Tutorial3_PPDF.new
    @pdf.title='20000 Leagues Under the Seas'
    @pdf.SetTitle(@pdf.title)
    @pdf.SetAuthor('Jules Verne')
    @pdf.PrintChapter(1,'A RUNAWAY REEF','20k_c1.txt')
    @pdf.PrintChapter(2,'THE PROS AND CONS','20k_c2.txt')
    @pdf.Output(File.join(@output_dir,'tutorial3.pdf'))
    puts "-------------- Finished Tutorial 3 --------------"
  end

  # ------------------------------------------------------------------
  class Tutorial4_PPDF < Tutorial3_PPDF
    attr_accessor :col, :y0
    
    def Header
      super()
      @y0 = self.GetY
    end
    def SetCol(col)
      # Set position at a given column
      @col = col
      x = 10+col*65
      SetLeftMargin(x)
      SetX(x)
    end
    def AcceptPageBreak
      # Method accepting or not automatic page break
      if @col < 2
        # Go to next column
        SetCol(@col+1)
        # Set ordinate to top
        SetY(@y0)
        # Keep on page
        false
      else
        # Go back to first column
        SetCol(0)
        # Page break
        true
      end
    end
    def ChapterTitle(num,label)
      super(num,label)
      @y0=GetY()
    end
    def ChapterBody(file)
      # Read text file
      mode = "r"
      # Binary if on Windows
      if Config::CONFIG['host_os'] =~ /msinw|mingw/
        mode += "b"
      end
      f=File.new(file,mode)
      txt=f.read
      f.close
      # Times 12
      SetFont('Times','',12)
      # Output justified text
      MultiCell(60,5,txt)
      # Line break
      Ln()
      # Mention in italics
      SetFont('','I')
      Cell(0,5,'(end of excerpt)')
      # Go back to first column
      SetCol(0)
    end
  end
  
  def test_tutorial4
    puts "-------------- Starting Tutorial 4 --------------"
    @pdf = Tutorial4_PPDF.new
    @pdf.col = 0
    @pdf.title='20000 Leagues Under the Seas'
    @pdf.SetTitle(@pdf.title)
    @pdf.SetAuthor('Jules Verne')
    @pdf.PrintChapter(1,'A RUNAWAY REEF','20k_c1.txt')
    @pdf.PrintChapter(2,'THE PROS AND CONS','20k_c2.txt')
    @pdf.Output(File.join(@output_dir,'tutorial4.pdf'))
    puts "-------------- Finished Tutorial 4 --------------"
  end


  # ------------------------------------------------------------------
  class Tutorial5_PPDF < TestPPDF

    # Load data
    def LoadData(file)
      # Read file lines
      mode = "r"
      f=File.new(file,mode)
      data = [ ]
      f.each_line do |line|
        data.push line.rstrip.split(';')
      end
      f.close
      data
    end

    # Simple table
    def BasicTable(header,data)
      # Header
      header.each do |col|
        Cell(40,7,col,1)
      end
      Ln()
      # Data
      data.each do |row|
        row.each do |col|
          Cell(40,6,col,1)
        end
        Ln()
      end
    end

    # Better table
    def ImprovedTable(header,data)
      # Column widths
      w= [40,35,40,45]
      # Header
      (0...header.length).each do |i|
        Cell(w[i],7,header[i],1,0,'C')
      end
      Ln()
      # Data
      data.each do |row|
        Cell(w[0],6,row[0],'LR')
        Cell(w[1],6,row[1],'LR')
        Cell(w[2],6,number_format(row[2]),'LR',0,'R')
        Cell(w[3],6,number_format(row[3]),'LR',0,'R',false,'http://www.fpdf.org/')
        Ln()
      end
      # Closure line
      Cell(w.reduce(:+),0,'','T')
    end
    
    def number_format(st)
      st.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
    end

    # Colored table
    def FancyTable(header,data)
      # Colors, line width and bold font
      SetFillColor(255,0,0)
      SetTextColor(255)
      SetDrawColor(128,0,0)
      SetLineWidth(0.3)
      SetFont('','B')
      # Header
      w=[40,35,40,45]
      (0...header.length).each do |i|
        Cell(w[i],7,header[i],1,0,'C',true)
      end
      Ln()
      # Color and font restoration
      SetFillColor(224,235,255)
      SetTextColor(0)
      SetFont('')
      # Data
      fill=false
      data.each do |row|
        Cell(w[0],6,row[0],'LR',0,'L',fill)
        Cell(w[1],6,row[1],'LR',0,'L',fill)
        Cell(w[2],6,number_format(row[2]),'LR',0,'R',fill)
        Cell(w[3],6,number_format(row[3]),'LR',0,'R',fill)
        Ln()
        fill = !fill
      end
      Cell(w.reduce(:+),0,'','T')
    end
  end
  
  def test_tutorial5
    puts "-------------- Starting Tutorial 5 --------------"
    @pdf = Tutorial5_PPDF.new
    @pdf.SetCompression(false)
    # Column titles
    header=['Country','Capital','Area (sq km)','Pop. (thousands)']
    # Data loading
    data=@pdf.LoadData('countries.txt')
    @pdf.SetFont('Arial','Bold',14)
    @pdf.AddPage()
    @pdf.BasicTable(header,data)
    @pdf.AddPage()
    @pdf.ImprovedTable(header,data)
    @pdf.AddPage()
    @pdf.FancyTable(header,data)
    @pdf.Output(File.join(@output_dir,'tutorial5.pdf'))
    puts "-------------- Finished Tutorial 5 --------------"
  end
  
  # ------------------------------------------------------------------
  class Tutorial6_PPDF < TestPPDF
    attr_accessor :styles, :HREF

    def initialize(orientation='P',unit='mm',format='A4')
      super(orientation,unit,format)
      # Initialization
      @styles = { 'B'=>false, 'I'=> false, 'U'=>false }
      @HREF = nil
    end

    def WriteHTML(html)
      # HTML parser
      html=html.gsub("\n",' ')
      re = Regexp.new("([^<]*)<([^>]+)>(.*)")
      while html
        m = re.match(html)
        if m
          text = m.captures[0]
          tag_contents = m.captures[1]
          html = m.captures[2]
        else
          text = html
          html = nil
        end
        # Text
        if (@HREF)
          PutLink(@HREF,text)
        else
          Write(5,text)
        end
        if m
          # Tag
          if(tag_contents[0,1] == '/')
            CloseTag(tag_contents[1,tag_contents.length-1].upcase)
          else
            # Extract attributes
            a2 = tag_contents.split(' ')
            tag = a2.shift.upcase
            attr = { }
            a2.each do |attrVal|
              nv = attrVal.split('=',2)
              nv[1] = nv[1][1,nv[1].length-2]
              attr[nv[0].upcase] = nv[1]
            end
            OpenTag(tag,attr)
          end
        end
      end
    end

    def OpenTag(tag,attr)
      # Opening tag
      if tag=='B' || tag=='I' || tag=='U'
        SetStyle(tag,true)
      elsif tag=='A'
        @HREF=attr['HREF']
      elsif tag=='BR'
        Ln(5)
      end
    end

    def CloseTag(tag)
      # Closing tag
      if tag=='B' || tag=='I' || tag=='U'
        SetStyle(tag,false)
      elsif tag == 'A'
        @HREF = nil
      end
    end

    def SetStyle(tag,enable)
      # puts "Setting style for #{tag} to #{enable}"
      # Modify style and select corresponding font
      @styles[tag] = enable
      SetFont '', (['B','I','U'].collect { |st| @styles[st] ? st : '' }).join('')
    end

    def PutLink(url,txt)
      # Put a hyperlink
      SetTextColor(0,0,255)
      SetStyle('U',true)
      Write(5,txt,url)
      SetStyle('U',false)
      SetTextColor(0)
    end

  end

  def test_tutorial6
	# This text is long than the version in the FPDF examples in order
	# to test multiple-line-wrap and to show the behavior with mixed
	# CJK/roman text.
    html='You can now easily print text mixing different styles: <b>bold</b>, <i>italic</i>, '+
    '<u>underlined</u>, or <b><i><u>all at once</u></i></b>!<br><br>You can also insert links on '+
    'text, such as <a href="http://www.fpdf.org">www.fpdf.org</a>, or on an image: click on the logo '+
	'and look at the long long text which wraps across multiple lines in a single extended call to Write. '
	htmlJA =
	'というと、すごく長くて一行ではなく何行が掛かるテクストをご欄してから「Prawn PDF」ってソフトが面白い意見になると思われました。'

    puts "-------------- Starting Tutorial 6 --------------"
    @pdf = Tutorial6_PPDF.new
    @pdf.SetCompression(false)
    # First page
    @pdf.AddPage()
    @pdf.SetFont('Arial','',20)
    @pdf.Write(5,"To find out what's new in this tutorial, click ")
    @pdf.SetFont('','U')
    i = @pdf.AddLink()
    @pdf.Write(5,'here',i)
    @pdf.SetFont('')
    # Second page
    @pdf.AddPage()
    @pdf.SetLink(i)
    @pdf.Image('logo.png',10,12,30,0,'','http://www.fpdf.org')
    @pdf.SetLeftMargin(45)
    @pdf.SetFontSize(14)
    @pdf.WriteHTML(html)
    @pdf.AddFont('Sazanami-Gothic','','sazanami-gothic.ttf')
    @pdf.SetFont('Sazanami-Gothic','',14)
	@pdf.WriteHTML(htmlJA)
    @pdf.Output(File.join(@output_dir,'tutorial6.pdf'))
    puts "-------------- Finished Tutorial 6 --------------"
  end

  def test_tutorial7
    puts "-------------- Starting Tutorial 7 --------------"
    @pdf = TestPPDF.new
    @pdf.AddFont('Calligrapher','','cranberries-ttfd-calligrapher.ttf')
    @pdf.AddPage()
    @pdf.SetFont('Calligrapher','',35)
    @pdf.Cell(0,10,'Enjoy new fonts with PrawnPDF!')
    @pdf.Ln()
    @pdf.Cell(0,10,'In UTF-8 even!')
    @pdf.Output(File.join(@output_dir,'tutorial7.pdf'))
    puts "-------------- Finished Tutorial 7 --------------"
  end

  def test_kanji # My new Kanji test
    puts "-------------- Starting Kanji test --------------"
    @pdf = TestPPDF.new
    @pdf.AddFont('Sazanami-Gothic','','sazanami-gothic.ttf')
    @pdf.AddFont('Sazanami-Mincho','','sazanami-mincho.ttf')
    @pdf.AddPage()
    @pdf.SetFont('Sazanami-Gothic','',35)
    @pdf.Cell(0,20,'PDFの書類を作成する')
    @pdf.Ln()
    @pdf.SetFont('Sazanami-Mincho','',35)
    @pdf.Cell(0,20,'（日本語で書いていても）')
    @pdf.Output(File.join(@output_dir,'kanji.pdf'))
    puts "-------------- Finished Kanji test --------------"
  end

end




