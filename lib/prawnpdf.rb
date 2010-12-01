# encoding: utf-8
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'rubygems'
require 'iconv'
require 'prawn'
require 'prawn/measurement_extensions'
require 'prawn/core/text/line_wrap'

module Prawn
  module Text
    # Subclass of Box which handles vertical alignment correctly.  This is
    # a bug in Prawn (reported on the Prawn tracket) which is particularly
    # troublesome in the FPDF Cell() call.
    class FixedBox < Box
      def process_vertical_alignment(text)
        if @vertical_align == :top then return end
        wrap(text)
        # The current height calculation returns (nLines*line_height)+ascender
        # That's slightly too big with most fonts since it includes
        # the space outside of (ascender+descender) for the final line
        adjusted_height = (height - @document.font.height) + @ascender + @descender
        case @vertical_align
        when :center
          @at[1] = @at[1] - (@height - adjusted_height) * 0.5
        when :bottom
          @at[1] = @at[1] - (@height - adjusted_height)
        end
        @height = height
      end
    end
    module Formatted
      # Same for Formatted:Box
      class FixedBox < Box
        def process_vertical_alignment(text)
          if @vertical_align == :top then return end
          wrap(text)
          # The current height calculation returns (nLines*line_height)+ascender
          # That's slightly too big with most fonts since it includes
          # the space outside of (ascender+descender) for the final line
          adjusted_height = (height - @document.font.height) + @ascender + @descender
          case @vertical_align
          when :center
            @at[1] = @at[1] - (@height - adjusted_height) * 0.5
          when :bottom
            @at[1] = @at[1] - (@height - adjusted_height)
          end
          @height = height
        end
      end
    end
  end
  module Core
    module Text
      # These are subclasses of Prawn's internal LineWrap object.
      # When laying out text, you must be able to control whether
      # or not character-based wrapping occurs in certain circumstances.
      # For instance, when drawing text across a line, at a point when
      # it's near the right margin, if the new text cannot be drawn with
      # standard word-based line wrapping, we want to call to fail
      # so that we draw that word on the next line.
      # However, when drawing a new line, if the word can't be drawn
      # with word-based line wrapping, it is desired to go ahead and use
      # char-based line wrapping (the way the Prawn code works by default).
      # To control this, LineWrap is overridden for both Text::Box and
      # Text::Formatted::Box, a new char_wrap_prohibited instance
      # variable is added, and this variable is implemented in the function
      # end_of_the_line.
      # 
      # This is used to implement the FPDF Write() call.
      class MyLineWrap < LineWrap
        attr_accessor :char_wrap_prohibited
        
        def end_of_the_line(segment)
          if @char_wrap_prohibited || @output =~ @word_division_scan_pattern
            if segment =~ new_regexp("^#{hyphen}") &&
                @output !~ new_regexp("[#{break_chars}]$")
              remove_last_output_word
            end
          else
            wrap_by_char(segment)
            @accumulated_width = compute_output_width
          end
        end

      end
      module Formatted
        class MyLineWrap < LineWrap
          attr_accessor :char_wrap_prohibited
          attr_reader :accumulated_width
          
          def end_of_the_line(segment)
            if @char_wrap_prohibited || (@line_output + @output) =~ @word_division_scan_pattern
              if segment =~ new_regexp("^#{hyphen}") &&
                  @output !~ new_regexp("[#{break_chars}]$")
                remove_last_output_word
              end
            else
              wrap_by_char(segment)
            end
          end
        end
      end
    end
  end
end
  
  
module PrawnPDF

  # These are extensions to Wrap for the Text::Box and 
  # Formatted:Box cases.  
  # They don't actually change the functionality of wrap() itself, 
  # but they invoke the local versions of LineWrap defined above.
  module PrawnPDFWrap
    def setup(char_wrap_prohibited)
      if @line_wrap.class != Prawn::Core::Text::MyLineWrap
        @line_wrap = Prawn::Core::Text::MyLineWrap.new
      end
      @line_wrap.char_wrap_prohibited = char_wrap_prohibited
    end
    
    # Currently unused, this was an experiment in how to get
    # the width of a successful tb.render.
    def consumed_char_count
      @line_wrap.consumed_char_count
    end

  end
  
  module PrawnPDFFormattedWrap
    def setup(char_wrap_prohibited)
      # puts "In PrawnPDFFormattedWrap.setup"
      if @line_wrap.class != Prawn::Core::Text::Formatted::MyLineWrap
        @line_wrap = Prawn::Core::Text::Formatted::MyLineWrap.new
      end
      @line_wrap.char_wrap_prohibited = char_wrap_prohibited
    end
    
    # Currently unused, this was an experiment in how to get
    # the width of a successful tb.render.
    def consumed_char_count
      # puts "In PrawnPDFFormattedWrap.consumed_char_count, value is #{@line_wrap.consumed_char_count}"
      @line_wrap.consumed_char_count
    end
    
    # Currently unused, this was an experiment in how to get
    # the width of a successful tb.render.
    def accumulated_width
      # puts "In PrawnPDFFormattedWrap.accumulated_width, value is #{@line_wrap.accumulated_width}"
      @line_wrap.accumulated_width
    end

  end

  Prawn::Text::Box.extensions << PrawnPDFWrap
  Prawn::Text::Formatted::Box.extensions << PrawnPDFFormattedWrap
  
  # A rectangle-like class: keeps four numbers accessible by name
  class Margins < Array
    def initialize(l,t,b,r)
      super()
      push l, t, b, r
    end
    def left() self[0] end
    def left=(new) self[0] = new end
    def top() self[1] end
    def top=(new) self[1] = new end
    def right() self[2] end
    def right=(new) self[2] = new end
    def bottom() self[3] end
    def bottom=(new) self[3] = new end
    def copyfrom(other)
      self.left, self.top, self.right, self.bottom = other[0,4]
    end
    def multiply(other)
      self.each_index do |i| self[i] = self[i]*other[i] end
    end
    def to_s
      "l:#{self[0]} t:#{self[1]} r:#{self[2]} b:#{self[3]}"
    end
    # Is any component != 0?
    def any?
      count(0) != length
    end
  end
  
  # Class to carry around information about links
  class LinkInfo
    attr_reader :id
    attr_accessor :left, :bottom, :right, :top
    attr_accessor :url
    attr_accessor :page, :y
    def initialize(url = nil)
      @url = url
    end
    def fromMargins(margins)
      @left = margins.left
      @top = margins.top
      @right = margins.right
      @bottom = margins.bottom
    end
    def complete?
      left and bottom and right and top and (url or (page and y))
    end
  end

  # 
  # This module has the unfortunate task of emulating an FPDF-style 
  # interface to PDF creation on top of Prawn.  There are several
  # problems with this, including:
  # 1.  In Prawn (0,0) is the top left corner inside the margin, whereas
  #     in FPDF it is the corner of the paper.
  #     => Therefore we keep the margin around and transform the
  #       coordinates manually.  We always keep Prawn set to the
  #       canvas, and never leave a bounding box set (we set some
  #       temporarily to do layout of text).
  # 2.  Prawn has no concept of a current X position; the library only
  #     maintains a y position.
  #     => Therefore we keep an explicit @cur_x
  # 3.  FPDF has three different "current colors": Drawing, Text, and
  #     Fill.  Prawn, like PDF itself, has fill and stroke colors.
  #     => Therefore we maintain the fill and text colors separately
  #        and set the appropriate one before every graphic operation
  # 4.  In FPDF, strings must be given in the font's encoding.
  #     Prawn sensibly uses UTF-8.
  #     => Everything in Rails should be UTF-8 already
  # 5.  Font style parameters are quite different.
  #     => The pstyle and SetFont routines re-interpretation,
  #       using Prawn's font_family feature to provide interpretation
  #       Underline is especially problematic.  It is implemented
  #       for the Write() call using Prawn's Text::Formatted::Box.
  #       However, all attempts to port Cell() from the current
  #       Text::Box to Text::Formatted::Box have failed, so 
  #       current SetFont('','U') is only functional for Write().
  # 6.  In FPDF, Margins and Title can be set at anytime. In Prawn,
  #     they are part of the constructor for Prawn::Document.
  #     => Therefore we delay document construction until AddPage
  #         is called
  # 7.  FPDF allows very flexible timing with regards to the 
  #     creation and settling of links.  To support that same
  #     model, we generate all non-URI links in a second pass.
  # 8.  FPDF provides a callback-style header/footer interface;
  #     Prawn essentially counts on doing header/footers outside
  #     of standard text layout in a second pass.  We provide
  #     the FPDF-style interface, but actually generate the
  #     headers/footers in a second pass when the document is
  #     closed.  One particular consequence of this is that 
  #     the Header callback will be invoked twice for each page.
  #     The first time will be when the page is started,
  #     but all graphic operations will be ignored; this is done
  #     just to determine the size of the header for the page.
  #     When the document is closed, it will be called again
  #     and the header will actually be drawn to the page.
  class PPDF
    include Prawn::Measurements
    
    # Access to the underlying Prawn::Document object
    attr_reader :pdoc, :last_cell_height
    
    # Constructor (as in FPDF).  Subclasses may override this to add their
    # own initialization after this has been called.
    # In particular, it's legal to call SetFont from the
    # constructor to establish a different default font.
    # Without a subclass, the default font is Helvetica.
    def initialize(orientation='P',unit='mm',format='A4')
      # puts "In PPDF.initialize"
      super()
      # Will be initialized later in make_document, so as to give the
      # client a chance to call the Set* routines for the document
      # header
      @pdoc = nil
      # converter from ISO-8859-1 to UTF-8
      @ic = ::Iconv.new('UTF-8','iso-8859-1')
      # callable for header
      @header = nil
      # callable for footer
      @footer = nil
      # Value that indicates where page number should be placed
      @page_alias = nil
      # Items for document header -- accumulated then used in make_document
      @info = { }
      @margins = Margins.new( 1.cm, 1.cm, 1.cm, 2.cm ) # left, top, right, bottom
      @layout = playout(orientation) || :portrait
      @page_size = ppage_size(format)
      @compression = true
      # The conversion method to call for FPDF units, if it is not points
      if unit == 'pt'
        @unit = nil
        @inverse_unit = nil
      elsif unit == 'mm'
        @unit = self.method(:mm2pt)
        @inverse_unit = self.method(:pt2mm)
      elsif unit == 'cm'
        @unit = self.method(:cm2pt)
        @inverse_unit = self.method(:pt2cm)
      elsif unit == 'in'
        @unit = self.method(:in2pt)
        @inverse_unit = self.method(:pt2in)
      else
        raise StandardError, "Unsupported unit parameter #{unit}"
      end
      # Whether we have entered a page yet (Prawn and FPDF have different
      # rules about what can come when)
      @page_started = nil
      
      # A temporary holding place for any font families registered
      # before the Prawn::Document object is created
      @temp_font_families = { }

      # Prawn is a little ambiguous or whether we can read back
      # the font family separately from the style, so we hang
      # onto everything. Also, in FPDF, you can (and are encouraged
      # to) set the font prior to the first page, whereas in 
      # Prawn it's not allowed.
      @font_family = 'Helvetica'
      @font_style = nil # In Prawn format, i.e., a label
      # Unlike real fonts, FPDF presents underline as a font 
      # attribute.  We keep track of whether it is on and use
      # Prawn's Text::Formatted to take care of it.
      @underline = false
      # The font size to initialize in AddPage if the user does 
      # not call SetFontSize before then
      @pre_font_size = 12
      # FPDF has a current x position as well as a current y position
      # To facilitate drawing, we keep the position in Prawn's
      # inside-the-margin, bottom-up coordinates.
      # These values are not set to real values until AddPage().
      @cur_x = 0
      @cur_y = 0
      
      # This value is needed by FPDF's Ln() function
      @last_cell_height = 0
      
      # FPDF keeps an (undocumented) 1mm left and right margin within cells
      @cell_margin = 1.mm

      # Although FPDF's Drawing color corresponds directly
      # to Prawn's stroke color, FPDF keeps Text and Fill colors
      # seperately, so we have to as well.
      # We keep them in hex format, Prawn's natural form.
      @current_text_color = Prawn::Graphics::Color.rgb2hex([0,0,0])
      @current_fill_color = Prawn::Graphics::Color.rgb2hex([0,0,0])
      
      # Whether or not auto-page-break mode is on
      @auto_page_break = true
      
      # Indicates that we are in page-alias-processing mode 
      # and should substitute the @page_alias string in all
      # text drawing
      @page_alias_active = false
      
      # Indicates we are in the second pass where we go back and
      # generate all the headers and footers.  Among other things,
      # this suppresses page breaks
      @header_footer_mode = false
      
      # Indicated we are in dry-run mode (used to execute headers
      # for measurement purposes)
      @dry_run_mode = false
      
      # A Hash indexed by page number.  The value of the is a graphics
      # state as returned by save_graphics_state capturing the graphics
      # state at the time the page was started.
      # This is used when doing the second-pass generation of the headers.
      @pre_header_state = { }
      
      # Another one, capturing the state at the time the page completed.
      # This is used when doing the second-pass generation of the footers.
      @pre_footer_state = {}

      # An array of the links in this document (indexed by link id)
      @links = [ ]
      
      # A hash indexed by page number.  The value is an array of
      # link_ids giving the links to be placed on each page.
      @links_by_page = {}
      
      # Whether Close() has been called or not
      @closed = nil
    end

    # -----------------------------------------------------------------------------
    # Routines to convert between FPDF values and Prawn values
    # -----------------------------------------------------------------------------

    # Convert FPDF format to Prawn :page_layout
    # If passed nil, returns nil
    def playout(layout)
      if layout == nil
        nil
      elsif layout.include? 'P'
        :portrait
      elsif layout.include? 'L'
        :landscape
      else
        raise StandardError, "Illegal orientation parameter #{layout}"
      end
    end

      # Convert FPDF format to Prawn page_size
    def ppage_size(format)
      if format == nil
        nil
      elsif format.class == String
        format.upcase
      elsif format.class == Array
        format
      else
        raise StandardError, "Illegal format parameter #{format}"
      end
    end
    
    # Convert RFPDF version of style to Prawn version
    def pstyle(style)
      style = style ? style.upcase : ''
      if style.include? 'B'
        if style.include? 'I'
          :bold_italic
        else
          :bold
        end
      else
        if style.include? 'I'
          :italic
        else
          :normal
        end
      end
    end

    # Converts FPDF version of alignment to Prawn version
    def palign(alignment)
      if alignment.class == Symbol
        alignment
      elsif (!alignment) or alignment.length == 0
        nil
      elsif alignment.include? 'L'
        :left
      elsif alignment.include? 'R'
        :right
      elsif alignment.include? 'C'
        :center
      elsif alignment.include? 'J'
        :justify
      else
        raise StandardError, "alignment parameter #{alignment} illegal"
      end
    end
    
    # Returns the logical intersection of two FPDF border specs
    def pborder_and(border1,border2)
      if (border1 == 0) || (border2 == 0)
        0
      elsif border1 == 1
        border2
      elsif border2 == 1
        border1
      else
        # Both are strings
        rv = '' 
        ["L","T","R","B"].each do |c|
          if (border1.include? c) and (border2.include? c)
            rv += c
          end
        end
        rv
      end
    end
    
    # Returns a Margins instance where left/top/right/bottom are either 0 or 1
    def pborder(border)
      if border.class == String
        Margins.new(*(['L','T','R','B'].map { |c| border.include?(c) ? 1 : 0 }))
      elsif border == 0
        return Margins.new(0,0,0,0)
      elsif border == 1
        return Margins.new(1,1,1,1)
      else
        raise StandardError, "border parameter #{border} illegal"
      end
    end

    # Converts 1-3 integers into a Prawn hex color
    def pcolor(r,g=nil,b=nil)
      if g
        Prawn::Graphics::Color.rgb2hex([r,g,b])
      else
        Prawn::Graphics::Color.rgb2hex([r,r,r])
      end
    end

    # Given an optional new FPDF x value, calculate the Prawn
    # x value or return the curent one.   Note that FPDF coords
    # may be negative.
    # Does not change the current value.
    def px(new_x=nil)
      if ! new_x then return @cur_x end
      if @unit then new_x = @unit.call(new_x) end
      if new_x >= 0
        new_x
      else
        @page_width + new_x
      end
    end
    # Converts from FPDF y coordinates to Prawn y coordinates.
    # FPDF-think is setting a top-down y relative to the
    # edge of the paper; we set up Prawn to use a bottom-up
    # system origined at the bottom of the page.
    # If new value is not supplied, returns the current value.
    # Does not change the current value.
    def py(new_y=nil)
      if ! new_y then return @cur_y end
      if @unit then new_y = @unit.call(new_y) end
      if new_y >= 0
        @page_height - new_y
      else
        -new_y
      end
    end

    # Translate w or h in FPDF user units to Prawn points
    def pwh(n)
      n ? (@unit ? @unit.call(n) : n) : nil
    end

    # Translate a distance in points to FPDF user units
    def fwh(n)
      @inverse_unit ? @inverse_unit.call(n) : n
    end
    
    # We should have to write this ourselves but Ruby doesn't put in the Hash class
    def readable_hash(hash)
      readable_elements = [ ]
      hash.each_pair do |k,v|
        if v.class == Hash
          vstr = readable_hash v
        else
          vstr = v.to_s
        end
        readable_elements.push "\"#{k}\" => #{vstr}"
      end
      "{ #{readable_elements.join(", ")} }"
    end

    # Routine to capture the graphics state (other than position)
    def save_graphics_state
      [
      @page_width,@page_height,
      Margins.new(*@margins[0,4]),
      @pdoc.line_width,
      @font_family,@font_style,@underline,@pdoc.font_size,
      @current_text_color, @current_fill_color, @pdoc.stroke_color 
      ]
    end
    
    # Routine to restore the graphics state (other than position)
    def restore_graphics_state(state)
      @page_width,@page_height,
      @margins,
      @pdoc.line_width,
      @font_family,@font_style,@underline,@pdoc.font_size,
      @current_text_color, @current_fill_color, @pdoc.stroke_color \
        = *state
      @pdoc.font @font_family, :style=>@font_style
    end
    
    # -----------------------------------------------------------------------------
    # Link Handling
    # -----------------------------------------------------------------------------

    # Return new LinkID.
    def AddLink()
      @links.push LinkInfo.new()
      @links.length-1
    end

    def SetLink(link_id,y=0,page=-1)
      if y == -1 then y = self.GetY end
      if page == -1 then page = @pdoc.page_number end
      li = @links[link_id]
      li.page, li.y = page, py(y)
    end
    
    def Link(x,y,w,h,link)
      self.internal_link(px(x),py(y),px(x)+pwh(w),py(y)-pwh(h),link)
    end
    
    def internal_link(left,top,right,bottom,link)
      if link.class == String
        # puts "Link_annotation (#{left},#{bottom},#{right},#{top}) #{link}"
        @pdoc.link_annotation([left,bottom,right,top],:Border=>[0,0,0],
          :A=>{:S=>:URI,:URI=>Prawn::Core::LiteralString.new(link)})
      elsif
        @links_by_page[@pdoc.page_number] ||= []
        @links_by_page[@pdoc.page_number] << link
        li = @links[link]
        li.fromMargins(Margins.new(left,top,right,bottom))
      end
    end

    # Called from Close
    def emit_link link_id
      li = @links[link_id]
      if !li.complete?
        raise StandardError, "Link id #{link_id} was never defined"
      end
      # puts "Emitting xyz link covering (l:#{li.left},b:#{li.bottom},r:#{li.right},t:#{li.top}) to page #{li.page} (0,#{li.y})"
      @pdoc.link_annotation([li.left,li.bottom,li.right,li.top],:Border=>[0,0,0],
        :Dest=>@pdoc.dest_xyz(0,li.y,nil,
          @pdoc.state.store[@pdoc.state.store.object_id_for_page(li.page)]))
    end

    # -----------------------------------------------------------------------------
    # Management of global state (accumulated prior to lazy page creation)
    # -----------------------------------------------------------------------------
    # Really, we should check that no page has been created yet in all of 
    # these

    def SetAuthor(author,isUtf8=true)
      @info[:Author] = isUtf8 ? author : @ic.conv(author)
    end
    def SetCreator(creator,isUtf8=true)
      @info[:Creator] = isUtf8 ? creator : @ic.conv(creator)
    end
    def SetKeywords(keywords,isUtf8=true)
      if ! isUtf8
        keywords = keywords.map { |kw| @ic.conv(kw) }
        @info[:Keywords] = keywords.join(' ')
      end
    end
    def SetSubject(subject,isUtf8=true)
      @info[:Subject] = isUtf8 ? subject : @ic.conv(subject)
    end
    def SetTitle(title,isUtf8=true)
      @info[:Title] = isUtf8 ? title : @ic.conv(title)
    end
    def SetCompression(comp)
      @compression = comp
    end
    # 'mm', 'cm', 'in', or 'pt'
    def SetUnit(unit)
      @unit = unit
    end
    # This procedure has no effect in PrawnPDF
    def SetDisplayMode(zoom,layout)
      nil
    end
    # -----------------------------------------------------------------------------
    # Management of margins (these affect FPDF->Prawn coordinate conversions
    # and formatting, but do not change the Prawn drawing coordinates.
    # -----------------------------------------------------------------------------
    def SetLeftMargin(lm)
      lm = pwh(lm)
      @margins.left = lm
      if @cur_x < lm
        @cur_x = lm
      end
    end
    def SetTopMargin(tm)
      @margins.top = pwh(tm)
    end
    def SetRightMargin(rm)
      @margins.right = pwh(rm)
    end
    def SetMargins(lm,tm,rm=nil)
      @margins.left = pwh(lm)
      @margins.top = pwh(tm)
      if rm
        @margins.right = pwh(rm)
      end
    end
    def SetAutoPageBreak(auto,margin=nil)
      @auto_page_break = auto
      if margin
        @margins.bottom = pwh(margin)
      end
    end
    
    # One important difference between PrawnPDF and FPDF is that in PrawnPDF,
    # the pages alias only works in the Header and Footer, not in normal text.
    def AliasNbPages(page_alias='{nb}')
      @page_alias = page_alias
    end
    

    # -----------------------------------------------------------------------------
    # Management of graphics state
    # -----------------------------------------------------------------------------

    # Handling of current pen position.
    def GetX
      @inverse_unit.call(@cur_x)
    end
    # Prawn is keeping a bottom-up y set relative to the margin;
    # FPDF wants a top-down y set relative to the edge of the 
    # paper
    def GetY
      @inverse_unit.call(@page_height - @cur_y)
    end
    def SetX(new_x)
      # puts "Setting cur_x to #{px(new_x)}"
      @cur_x = px(new_x)
    end
    def SetY(new_y)
      @cur_x = @margins.left
      @cur_y = py(new_y)
    end
    def SetXY(new_x,new_y)
      SetX new_x
      SetY new_y
    end
    
    def SetDrawColor(r,g=nil,b=nil)
      @pdoc.stroke_color = pcolor(r,g,b)
    end
    def SetTextColor(r,g=nil,b=nil)
      @current_text_color = pcolor(r,g,b)
    end
    def SetFillColor(r,g=nil,b=nil)
      @current_fill_color = pcolor(r,g,b)
    end
    
    # Adds a single TrueType font file to the system as a single-
    # font family.  No other fonts can later be registered in this
    # family (use AddFontFamily instead if you have multiple fonts
    # in a family).  Unlike in FPDF with it's built-in fonts,
    # the filename must be specified; but no preprocessing of fonts
    # is required.  
    #
    # This is exactly equivalent to calling AddFontFamily(family,file).
    def AddFont(family,style,file)
      AddFontFamily(family,file)
    end
    
    # PrawnFPDF supports adding fonts in families of four or more
    # styles.  To add a family, call this routine with the name of the
    # family, and the path to the TrueType font file for the regular
    # font in that family.  You may optionally provide the bold, italic,
    # and boldItalic fonts to be included.
    #
    # You can use this method to override the initially installed
    # default PostScript fonts, although that is not recommended.
    def AddFontFamily(family,normal,boldFont=nil,italicFont=nil,boldItalicFont=nil)
      update_hash = @pdoc ? @pdoc.font_families : @temp_font_families
      update_hash.update(
        family => {:bold        => boldFont || normal,
                   :italic      => italicFont || normal,
                   :bold_italic => boldItalicFont || normal,
                   :normal      => normal })
    end
    
    # Sets the current font.  
    # @param family: the pathname of a TrueType font, or a family previously
    #   registered via AddFontFamily/AddFont.
    # @param style: 'B', 'I'
    def SetFont(family,style=nil,size=nil)
      # puts "SetFont '#{family}' '@{style}' '@{size}'"
      if family == '' 
        family = nil 
      end
      family ||= @font_family
      # Sigh, FPDF registers 'Times-Roman' as 'Times'
      if family == 'Times' and !@pdoc.font_families.has_key?('Times')
        family = 'Times-Roman'
      end
      @font_family = family
      @font_style = pstyle(style)
      @underline = (style != nil) && style.include?('U')
      if @pdoc
        # puts "Setting font_family #{@font_family} style #{@font_style} underline #{@underline} from args '#{family}','#{style}'"
        @pdoc.font @font_family, :style => @font_style
      end
      if size
        self.SetFontSize size
      end
    end
    
    # Some code seems to call this although I can't see it in the docs
    # or other implementations of the API anywhere
    def SetFontStyle(style=nil,size=nil)
      self.SetFont(nil,style,size)
    end

    def SetFontSize(size)
      if !@page_started
        # puts "Setting @pre_font_size to #{@pre_font_size}"
        @pre_font_size = size
      else
        # puts "Setting Prawn font_size to #{size}"
        @pdoc.font_size size
      end
    end
    
    # -----------------------------------------------------------------------------
    # Document and Page creation
    # -----------------------------------------------------------------------------

    # Creates the Prawn PDF document object based on the currently
    # accumulated information from the methods above.
    def make_document
      if @pdoc
        return
      end
      @pdoc = Prawn::Document.new(
        :info=>@info,
        :left_margin=>0,:top_margin=>0,:right_margin=>0,:bottom_margin=>0,
        :compress => @compression,
        :skip_page_creation=>true
        )
      # Now that there's a document,
      # Update any font families temporarily stashed away locally
      # puts "In make_document, @temp_font_families is '#{readable_hash(@temp_font_families)}'"
      @pdoc.font_families.update(@temp_font_families)
      # puts "In make_document, @pdoc.font_families is '#{readable_hash(@pdoc.font_families)}'"
      # Because the FPDF tutorial uses this, many people are in the
      # habit.  Also, it makes the tutorials work...
      #if ! @temp_font_families.has_key? 'Arial'
      #  @pdoc.font_families['Arial'] = @pdoc.font_families['Helvetica']
      #end
    end
    
    # Can be overridden by subclasses to implement Header beahvoir.
    # When Header is called, the current point will be the top left
    # corner of the page inside the margins.  
    # Any drawing in Header will push the page content down on the 
    # page.
    # Note that Header will typically be invoked twice, so it should
    # not have any side effects.
    def Header
    end

    # Can be overridden by subclasses to implement Footer behavior.
    # When Footer is called, the bounds will be the entire page
    # (outside of margins).  Footer has no effect on page layout.
    def Footer
    end
    
    # Allows subclasses to take action when a page break is
    # triggered (including suppressing the break).
    # By default, this method just returns @auto_page_break,
    # but subclasses can override it to implement arbitrary text
    # flows by tweaking the margins and returning false.
    def AcceptPageBreak
      @auto_page_break
    end
    
    # Internal routine for determining whether a page break should
    # be carried out when graphics run over the current bottom margin.
    def page_break_ok
      (!@dry_run_mode) and (!@header_footer_mode) and self.AcceptPageBreak
    end
    
    # AddPage([string orientation ,[ mixed format]])
    # Description
    # Adds a new page to the document. If a page is already present, the Footer() method is called first to output the footer. Then the page is added, the current position set to the top-left corner according to the left and top margins, and Header() is called to display the header. 
    # The font which was set before calling is automatically restored. There is no need to call SetFont() again if you want to continue with the same font. The same is true for colors and line width. 
    # The origin of the coordinate system is at the top-left corner and increasing ordinates go downwards.
    def AddPage(orientation=nil,format=nil)
      if @page_started
        # Capture graphic state at footer time for use in eventual footer generation
        @pre_footer_state[@pdoc.page_number] = save_graphics_state
      end
      make_document
      @layout = playout(orientation) || @layout
      @page_size = ppage_size(format) || @page_size
      @pdoc.start_new_page(:size=>@page_size, :layout => @layout)
      # puts "Starting new page with margins #{@margins}"
      @page_height = @pdoc.bounds.height
      @page_width = @pdoc.bounds.width
      @cur_x = @margins.left
      @cur_y = @page_height - @margins.top
      # puts "Page width and height are (#{@page_width},#{@page_height}), position set to (#{@cur_x},#{@cur_y})"
      if ! @page_started
        # First-time setup of FPDF defaults
        # puts "Initializing prawn font #{@font_family} style #{@font_style} size #{@pre_font_size}"
        @pdoc.font @font_family, :style => @font_style
        @pdoc.font_size = @pre_font_size
        @pdoc.line_width = 0.2.mm
      end
      @page_started = true
      @pre_header_state[@pdoc.page_number] = save_graphics_state
      # Call header in dry_run_mode to get effect of sizing.
      # We don't actually image the header until the rest of the
      # document is done (so that we can know the page count)
      @dry_run_mode = true
      initial_state = save_graphics_state
      self.Header
      restore_graphics_state initial_state
      @dry_run_mode = false
    end
    
    def Close
      if !@closed
        if @page_started
          @pre_footer_state[@pdoc.page_number] = save_graphics_state
        end
        # Implement header/footers.  Since Prawn allows us to go back
        # and add to already-created pages, we just do all header/footers
        # after the document is done and we know how many pages
        # there are.
        # puts "Generating Headers and Footers"
        if @page_alias
          @page_alias_active = true
        end
        @header_footer_mode = true
        @pdoc.page_count.times do |i|
          @pdoc.go_to_page(i+1)
          restore_graphics_state @pre_header_state[i+1]
          @cur_x = @margins.left
          @cur_y = @page_height - @margins.top
          # puts "Doing page #{i+1} Header, position reset to (#{@cur_x},#{@cur_y})"
          self.Header
          restore_graphics_state @pre_footer_state[i+1]
          # puts "Doing page #{i+1} footer, position reset to (0,0)"
          @cur_x = 0
          @cur_y = 0
          self.Footer
          # puts "Page #{i+1} footer complete."
          if @links_by_page[i+1]
            @links_by_page[i+1].each do |link_id|
              emit_link link_id
            end
          end
        end
        @header_footer_mode = false
        @page_alias_active = false
      end
      @closed = true
    end
    
    def Output(name=nil,dest=nil)
      Close()
      if !dest
        if !name
          dest = 'S'
        else
          dest = 'F'
        end
      end
      dest = dest.upcase
      if dest == 'F'
        @pdoc.render_file(name)
      elsif dest == 'S'
        @pdoc.render
      else
        raise StandardError, "Unsupported Output dest value #{dest}"
      end
    end
    
    def PageNo
      @pdoc.page_number
    end
    
    # -----------------------------------------------------------------------------
    # Graphics Operations
    # -----------------------------------------------------------------------------

    # str must be in UTF-8
    def GetStringWidth(str)
      make_document
      fwh(@pdoc.width_of(@pdoc.font.normalize_encoding(str)))
    end
    
    def Image(file,x=nil,y=nil,w=nil,h=nil,type=nil,link=nil)
      w = w == 0 ? nil : (w ? pwh(w) : nil)
      h = h == 0 ? nil : (h ? pwh(h) : nil)
      if (!w) or !h
        mode = "r"
        # Binary if on Windows
        if Config::CONFIG['host_os'] =~ /msinw|mingw/
          mode += "b"
        end
        f = File.new(file,mode)
        img_data = f.read
        f.close
        if file.downcase.end_with? '.png'
          im = Prawn::Images::PNG.new(img_data)
        elsif file.downcase.end_with? '.jpg'
          im = Prawn::Images::JPG.new(img_data)
        else
          raise StandardError, "Only PNG and JPG images are supported"
        end
        if !w
          if !h
            w, h = im.width, im.height
          else
            w = (h*im.width)/im.height
          end
        else
          h = (w*im.height)/im.width
        end
        img_data = nil
      end
      # See if it fits on the page and whether we should break if it doesn't
      if (!y) and h and (@cur_y < @margins.bottom+h) and page_break_ok
        self.AddPage
      end
      if !@dry_run_mode
        y = y ? py(y) : @cur_y
        x = x ? px(x) : @cur_x
        # puts "Outputting image(#{file},#{x},#{y},#{w},#{h}...)"
        ip = @pdoc.image(file,:at => [x,y], :width => w, :height => h)
        if link
          internal_link(x,y-h,x+w,y,link)
        end
      end
    end
    
    def SetLineWidth(width)
      @pdoc.line_width = pwh(width)
    end

    def Line(x1,y1,x2,y2)
      if ! @dry_run_mode
        @pdoc.stroke do
          # puts "Drawing line from (#{px(x1)},#{py(y1)}) to (#{px(x2)},#{py(y2)})"
          @pdoc.line [px(x1),py(y1)], [px(x2),py(y2)]
        end
      end
    end
    
    def Ln(h=nil)
      if h
        h = pwh(h)
      else
        h = @last_cell_height
      end
      @cur_x = @margins.left
      # puts "Ln: x -> #{@cur_x}, adjusting @cur_y from #{@cur_y} to #{@cur_y - h}"
      @cur_y = @cur_y - h
    end
    
    def Cell(w,h=0,txt='',border=0,ln=0,align='L',fill=nil,link=nil)
      # puts "Cell: Entry #{w} #{h} #{txt.length > 30 ? txt[0,30] : txt}, ln=#{ln} link=#{link}"
      cell_implementation(w,h,txt ? txt.gsub('\n','') : '',border,ln,align,fill,link,false,true)
    end
    
    def MultiCell(w,h,txt='',border=0,align='J',fill=nil)
      # puts "MultiCell: Entry #{w} #{h} #{txt.length > 20 ? txt[0,20] : txt}(len:#{txt.length}) brdr #{border}"
      if txt == nil then return end
      # We have to split up the implementation of border, because we might
      # generate a page break on any particular call to cell_implementation.
      first_cell = true
      txt.split("\r\n").each do |line|
        # puts "MultiCell: Line #{line.length > 20 ? line[0,20] : line}(len:#{line.length})"
        remainder, cw, ch = cell_implementation(w,h,line,0,2,align,fill,nil,false,false)
        multicell_border(border,first_cell,remainder,cw,ch)
        first_cell = false
        while remainder and remainder.length > 0
          # puts "MultiCell: remainder #{remainder.length > 20 ? remainder[0,20] : remainder}(len:#{remainder.length})"
          remainder, cw, ch = cell_implementation(w,h,remainder,0,2,align,fill,nil,true,false)
          multicell_border(border,first_cell,remainder,cw,ch)
        end
      end
      # Bizarre though it may seem, this appears to be the FPDF behavior
      @cur_x = @margins.left
    end
    
    # We have to draw each part of a multicell's border immediately after the
    # call to cell_implementation because the next piece might generate a page break.  
    # But, we only want to draw the relevant portion of the border on each call.
    def multicell_border(border,first_cell,remainder,w,h)
      if border == 0 then return end
      last_cell = (remainder == nil) || (remainder.length == 0)
      # puts "multicell_border border #{border} first_cell #{first_cell} last_cell #{last_cell}"
      border_internal(
        first_cell ? (last_cell ? border : pborder_and(border,'LTR')) :
                     (last_cell ? pborder_and(border,'LRB') : pborder_and(border,'LR') ),
        @cur_x,@cur_y+h,@cur_x+w,@cur_y)
    end
    
    # Implements the drawing of borders for the given rectangle
    # and the given FPDF border spec
    def border_internal(fborder,l,t,r,b)
      # puts "In border_internal with (#{l},#{t},#{r},#{b}) and border #{fborder}"
      border = pborder(fborder)
      if border.any?
        old_cap_style = @pdoc.cap_style
        @pdoc.cap_style :projecting_square
        mt = @pdoc.method(:move_to)
        lt = @pdoc.method(:line_to)
        @pdoc.stroke do
          @pdoc.move_to l, b
          (border.left != 0 ? lt : mt).call(l,t)
          (border.top != 0 ? lt : mt).call(r,t)
          (border.right != 0 ? lt : mt).call(r,b)
          (border.bottom != 0 ? lt : mt).call(l,b)
        end
        @pdoc.cap_style old_cap_style
      end
    end
    
    # Starting at (@cur_x,@cur_y), draw the given text.
    # w and h are in FPDF units
    # If w=0, set w to the distance to the right margin.
    # align can be left/center/right within the calculated or given w
    # if h is given, this call can trigger a page break if it won't
    # fit on the page.  If h==0, it is assumed to fit.
    # valign is always implicitly :center (although it doesn't matter if h==0)
    # border and fill as in Cell().
    # ln: 0:to the right 1:beginning of next line 2: below
    # If one_liner is true, clipping will be ignored (like spreadsheet text display)
    # If one_liner is nil, text that does not fit will be returned and should
    # be subsequently drawn with skip_encoding=true.  Note that if text overflows
    # and ln==0, the x/y position will still be at the end of the line.
    def cell_implementation(w=0,h=0,txt='',border=0,ln=0,align='',fill=nil,link=nil,
                            skip_encoding=false,one_liner=false)
      make_document
      w, h = pwh(w), pwh(h)
      h = h == 0 ? nil : h
      pre_h = h ? h : 0
      txt = txt ? txt : ''
      link = link == '' ? nil : link
      # Now decide if it fits on the page (only if height specified) and whether we should break
      if (@cur_y < @margins.bottom+pre_h) and page_break_ok
        self.AddPage
      end
      w = w == 0 ? @pdoc.bounds.width - (@margins.right + @cur_x) : w
      orig_y = @cur_y
      # puts "orig_y is #{orig_y}"
      remainder = nil
      if ! @dry_run_mode
        @last_cell_height = h
        if fill
          @pdoc.fill_color @current_fill_color
          @pdoc.fill do
            @pdoc.rectangle [@cur_x,@cur_y],w,h 
          end
        end
        if @page_alias_active
          txt = txt.gsub @page_alias,@pdoc.page_count.to_s
        end
        # puts "Defining bounding box with top left at (#{@cur_x},#{@cur_y}),width=>#{w},height=>#{h}"
        @pdoc.bounding_box [@cur_x,@cur_y],:width=>w,:height=>h do
          @last_cell_height = h
          if txt.length > 0
            @pdoc.fill_color @current_text_color
            # For one-liners, we don't want to respect clipping
            if one_liner
              y = @pdoc.bounds.top-@pdoc.font.ascender
              if h
                # Then do the equivalent of :valign => :center
                y -= (h-(@pdoc.font.ascender+@pdoc.font.descender))/2
              end
              align = palign(align)
              if align == :left
                x = @cell_margin
              else
                sw = @pdoc.width_of(@pdoc.font.normalize_encoding(txt))
                if align == :right
                  x = w - (@cell_margin+sw)
                else
                  x = (w - sw)/2
                end
              end
              @pdoc.draw_text(txt,:at => [x,y])
              if !h
                @last_cell_height = @pdoc.font_size
              end
            else
              # puts "Defining text box at (#{@cell_margin},#{@pdoc.bounds.top}), w #{w-2*@cell_margin}"
              # puts "Creating Box with txt #{txt.class} '#{txt}'"
              tb = Prawn::Text::FixedBox.new(txt,
                                        :at => [@cell_margin,@pdoc.bounds.top],
                                        :width => w - 2*@cell_margin,
                                        :align => palign(align),
                                        :valign=>:center,
                                        :skip_encoding=>skip_encoding,
                                        :document=>@pdoc)
              remainder = tb.render
              # For development and/or testing, we sometimes switch to Formatted::Box
              if tb.class == Prawn::Text::Formatted::FixedBox and remainder and remainder.length > 0
                remainder = remainder[0][:text]
              end
              # puts "tb.lineHeight #{tb.line_height}, ascender #{tb.ascender}, descender #{tb.descender} leading #{tb.leading}"
              if !h
                @last_cell_height = tb.height
              end
              #puts "TextBox height was #{tb.height}"
            end
          end
          border_internal(border,0,@pdoc.bounds.top,w,@pdoc.bounds.bottom)
        end
        if link
          lh = h ? h : @last_cell_height
          # puts "Cell_implementation: assigning link '#{link}'"
          self.internal_link(@cur_x,@cur_y,@cur_x+w,@cur_y-lh,link)
        end
      end
      if ln == 0
        # puts "Setting x to #{@cur_x+w}, restoring y to #{orig_y}"
        @cur_y = orig_y
        @cur_x += w
      elsif ln == 1
        @cur_x = @margins.left
        @cur_y = orig_y - (h ? h : @last_cell_height)
        # puts "New @cur_y is #{@cur_y}"
      else # ln == 2
        @cur_y = orig_y - (h ? h : @last_cell_height)
        # puts "New @cur_y is #{@cur_y}"
      end
      [remainder, w, h ? h : @last_cell_height]
    end
    
    def Rect(x,y,w,h,style='D')
      if !@dry_run_mode
        if style.includes? 'F'
          @pdoc.fill_color @current_fill_color
          @pdoc.fill do @pdoc.rectangle [px(x),py(y)],pwh(w),pwh(h) end
        end
        if style.includes? 'D'
          @pdoc.stroke do @pdoc.rectangle [px(x),py(y)],pwh(w),pwh(h) end
        end
      end
    end
    
    def Text(x,y,txt)
      if ! @dry_run_mode
        make_document
        @pdoc.fill_color @current_text_color
        if @page_alias_active
          txt = txt.gsub @page_alias,@pdoc.page_count.to_s
        end
        @pdoc.draw_text txt, :at => [px(x),py(y)]
      end
    end
    
    def Write(h,txt,link=nil)
      # puts "In Write for '#{txt}' of height #{h} with link #{link}"
      make_document
      @pdoc.fill_color @current_text_color
      if @page_alias_active
        txt = txt.gsub @page_alias,@pdoc.page_count.to_s
      end
      lines = txt.split("\n")
      lines.each_index do |li|
        # puts "Write: Doing line '#{lines[li]}'"
        remainder = write_implementation(h,lines[li],link,false,true)
        while remainder and remainder.length > 0
          # puts "Write: Got remainder '#{remainder}'; doing line break"
          self.Ln(h)
          remainder = write_implementation(h,remainder,link,true,false)
        end
        if (li < lines.length-1)
          # puts "Outputting Ln for hard break"
          self.Ln(h)
        end
      end
    end
  
    def write_implementation(h,txt,link,skip_encoding=false,char_wrap_prohibited=false)
      # puts "In write_implementation for '#{txt}' cwp '#{char_wrap_prohibited}'"
      make_document
      h = pwh(h)
      # Now decide if it fits on the page and whether we should break
      if (@cur_y < @margins.bottom+h) and page_break_ok
        self.AddPage
      end
      orig_y = @cur_y
      # puts "position is (#{@cur_x},#{orig_y})"
      w = @pdoc.bounds.width - (@cur_x + @margins.right)
      remainder = nil
      if txt.length > 0
        @pdoc.fill_color @current_text_color
        tb = Prawn::Text::Formatted::Box.new([{:text=>txt,:styles => @underline ? [ :underline ] : nil}],
                                  :at => [@cur_x,@cur_y],
                                  :width => w,
                                  :align => :left,
                                  :valign => :top,
                                  :single_line => true,
                                  :skip_encoding => skip_encoding,
                                  :document => @pdoc)
        tb.setup(char_wrap_prohibited)
        begin
          w = @pdoc.width_of(txt)
          # puts "Text box available width is #{tb.available_width}"
          remainder = tb.render :dry_run => @dry_run_mode
          # This is just because during development the code flip-flopped between
          # Formatted::Box and Box several times.  It's still useful to do that
          # for testing.
          if tb.class == Prawn::Text::Formatted::Box and remainder and remainder.length > 0
            remainder = remainder[0][:text]
          end
          h = tb.height()
          # Other implementations of figuring out the drawn width:
          # This one if only good for Text::Box and doesn't work because 
          # tb.text doesn't include trailing spaces
          # w = @pdoc.width_of(remainder ? tb.text : txt)
          # This one works great but only with Text::Box
          # w = @pdoc.width_of(txt[0,tb.consumed_char_count])
          # This seems like it should work with Formatted:Box, but doesn't.
          # w = remainder ? tb.accumulated_width : @pdoc.width_of(txt)
          # puts "w #{w} h #{h} remainder '#{remainder}'"
        rescue Prawn::Errors::CannotFit
          # puts "No text made it out"
          remainder = @pdoc.font.normalize_encoding(txt)
          w = 0
        end
      end
      if link && (w > 0)
        # puts "Calling internal_link with (#{@cur_x},#{@cur_y},#{@cur_x+w},#{@cur_y-h}), #{link}"
        self.internal_link(@cur_x,@cur_y,@cur_x+w,@cur_y-h,link)
      end
      # puts "Setting x to #{@cur_x+w}, restoring y to #{orig_y}"
      @cur_x = @cur_x + w
      @cur_y = orig_y
      # puts "Returning remainder '#{remainder}'"
      remainder
    end
    

  
  
  end
  
end


