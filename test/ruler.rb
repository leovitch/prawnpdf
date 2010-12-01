
require 'test/unit'

require File.dirname(__FILE__) + '/../lib/prawnpdf'

class PrawnPDFTest < Test::Unit::TestCase

  # Explicitly include the module
  include PrawnPDF
  
  def initialize(*args)
    super(*args)
    @output_dir = File.join(File.dirname(__FILE__),'test_output')
    if ! File.directory? @output_dir
      Dir.mkdir @output_dir
    end
    
  end

  def test_tutorial1
    pdf = PPDF.new(orientation='P',unit='cm')
    pdf.AddFontFamily('Arial','/Library/Fonts/Arial.ttf',
            '/Library/Fonts/Arial Bold.ttf',
            '/Library/Fonts/Arial Italic.ttf',
            '/Library/Fonts/ArialBold Italic.ttf')
    pdf.AddPage(orientation='P',format='A4')
    pdf.pdoc.stroke_bounds
    (1...21).each do |i|
      pdf.Line(i,0,i,30)
    end
    pdf.Output(File.join(@output_dir,'ruler_prawnpdf.pdf'),'F')
  end

end

