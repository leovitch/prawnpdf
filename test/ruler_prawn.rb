

require 'rubygems'
require 'prawn'
require 'prawn/measurement_extensions'
Prawn::Document.generate("test_output/ruler_prawn.pdf", :margin => 1.cm, :page_size => 'A4') do |pdf|
  pdf.start_new_page(:size=>'A4')
  pdf.stroke_bounds
  pdf.canvas do
      pdf.stroke do
        (0...22).each do |i|
          pdf.line [i.cm,0], [i.cm,30.cm]
        end
      end
      (0...22).each do |i|
        pdf.draw_text i, :at => [i.cm,1.cm]
      end
  end

end