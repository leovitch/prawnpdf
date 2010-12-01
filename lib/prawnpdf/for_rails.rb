require 'prawnpdf'
require 'i18n'

module PrawnPDF

	# FPDF-alike class for use in Rails
	# This class differs from PPDF only in its default font handling.
	# When this class is instantiated, it will look up :default_pdf_normal_font
	# in the locale. If that is defined, it will be used as the default font.
	# Symbols for :default_pdf_bold_font, :defualt_pdf_italic_font,
	# and :default_pdf_bold_italic_font may also be defined if those effects
	# are desired.  This family of one or more fonts will be set as the default
	# and will also be available by calling SetFont('Default').
	#
	# If :default_pdf_normal_font is not defined, Helvetica will be set as the
	# default font.
	#
	# As with the PPDF class, you may add any .ttf font you want simply by calling 
	# AddFontFamily with a family name and the full path to 1 to 4 .ttf files.
	# No pre-processing or other preparation of the fonts is needed.
	class RPDF < PPDF
		def initialize(orientation='P',unit='mm',format='A4')
			super(orientation,unit,format)
			default_font = I18n::t(:default_pdf_normal_font,:default=>'Helvetica')
			if default_font != 'Helvetica'
				AddFontFamily('Default',
						default_font,
						I18n::t(:default_pdf_bold_font,:default=>default_font),
						I18n::t(:default_pdf_italic_font,:default=>default_font),
						I18n::t(:default_pdf_bold_italic_font,:default=>default_font)
				)
				SetFont('Default','')
			else
				SetFont('Helvetica','')
			end
		end
	end

end