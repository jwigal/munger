begin
  require 'prawn'
rescue LoadError
  require 'rubygems'
  require 'prawn'
end

module Munger #:nodoc:
  module Render #:nodoc:
    class Pdf
    
      attr_reader :report, :classes, :group_style, :group_font, :table_format, :document_options,
                  :pdf, :group_font_face, :header_font, :header_font_face, :footer_font, :footer_font_face
      def pdf
        @pdf ||= Prawn::Document.new(@document_options)
      end
      
=begin

Public: Create a new Munger::Render::Pdf object

report  - The Munger::Report to be rendered.
options - A Hash with options for rendering the PDF.

    options = {
      :group_style => {:style => :bold},
      :group_font => {:size => 16, :font => "Helvetica"},
      :table_format => {:header => true, :row_colors => %w(ffffff ede5b2), :cell_style => {:border_width => 0} },
      :document => {:page_layout => :landscape, :margin => [50,50]},
      :header => {:size => 12, :font => "Helvetica", :text => ""},
      :footer => {:size => 12, :font => "Helvetica", :text => ""}
    }

Examples

  Munger::Render::Pdf.new()
  # => 'TomTomTomTom'

Returns a Munger::Render::Pdf


=end      
      
      def initialize(report, options = {})
        @report = report
        set_group_style(options[:group_style])
        set_group_font(options[:group_font])
        set_table_format(options[:table_format])
        set_document_options(options[:document])
        set_header_options(options[:header])        
        set_footer_options(options[:footer])        
        self
      end


      def render
        if @report.process_data.any?{|row| row[:meta][:group_header]}
          header = @report.columns.collect{|column| @report.column_title(column)}
          table_data = [header]
          @report.process_data.each do |row|
            if row[:meta][:group_header]              
              draw_table( table_data ) if table_data.size > 1
              conditional_page_break
              pdf.font(@group_font_face, @group_font) { 
                pdf.text row[:meta][:group_value].to_s, @group_style 
              }
              table_data = [header]
            elsif row[:meta][:data] 
              table_data << @report.columns.collect do |column|
                row[:data][column].to_s
              end 
            end
          end 
          draw_table table_data         
        else
          table_data = []
          table_data = [@report.columns.collect{|column| @report.column_title(column)}]
          @report.process_data.each do |row|
            table_data << @report.columns.collect do |column|
              row[:data][column].to_s
            end 
          end
          draw_table table_data 
        end
        
        pdf.repeat(:all, :dynamic => true) do 
          pdf_header
          pdf_footer
          pdf_page_numbers
        end
        pdf 
      end
      
      def valid?
        @report.is_a? Munger::Report
      end
      
      protected

      def set_header_options(options = nil)
        options = {} if !options
        default = {:size => 12, :font => "Helvetica", :text => ""}
        @header_font = default.merge(options)        
        @header_font_face = @header_font.delete(:font)
        @header_text = @header_font.delete(:text)
      end

      def set_footer_options(options = nil)
        options = {} if !options
        default = {:size => 12, :font => "Helvetica", :text => ""}
        @footer_font = default.merge(options)        
        @footer_font_face = @footer_font.delete(:font)
        @footer_text = @footer_font.delete(:text) || ""
      end

      def set_document_options(options=nil)
        options = {} if !options
        default = {:page_layout => :landscape, :margin => [50,50]}
        @document_options = default.merge(options)        
      end
      
      def set_table_format(options=nil)
        options = {} if !options
        default = {
          :header => true, :row_colors => %w(ffffff ede5b2), :cell_style => {:border_width => 0},
          :font_size => 10, :font_face => "Helvetica"
        }
        @table_format = default.merge(options)
        @table_font_size = @table_format.delete(:font_size)        
        @table_font_face = @table_format.delete(:font_face)        
      end
      
      def set_group_style(options = nil)
        options = {} if !options
        default = {:style => :bold}
        @group_style = default.merge(options)        
      end

      def set_group_font(options = nil)
        options = {} if !options
        default = {:size => 16, :font => "Helvetica"}
        @group_font = default.merge(options)        
        @group_font_face = @group_font.delete(:font)
      end
      
      def draw_table(data)
        pdf.font(@table_font_face, :size => @table_font_size) do
          pdf.table(data, @table_format) do
            row(0).borders = [:bottom]
            row(0).border_width = 2
            row(0).font_style = :bold
          end    
        end
        pdf.move_down 20    
      end
      
      def conditional_page_break
        pdf.start_new_page if (pdf.bounds.bottom - pdf.cursor).abs < 50
      end
      
      def pdf_header
        pdf.stroke { pdf.line [ pdf.bounds.left, pdf.bounds.top + 8], [pdf.bounds.right, pdf.bounds.top + 8]}
        pdf.bounding_box [ pdf.bounds.left, pdf.bounds.top + 20], :width => pdf.bounds.width do
          pdf.font(@header_font_face, @header_font) { pdf.text @header_text }
        end        
      end
      
      def pdf_footer
        pdf.stroke { pdf.line [ pdf.bounds.left, pdf.bounds.bottom + 20], [pdf.bounds.right, pdf.bounds.bottom + 20]}
        pdf.bounding_box [ pdf.bounds.left, pdf.bounds.bottom + 15], :width => pdf.bounds.width do
          pdf.font(@footer_font_face, @footer_font) { pdf.text @footer_text }
        end        
      end
      
      def pdf_page_numbers
        pdf.draw_text pdf.page_number, :at => [pdf.bounds.right - 5, 0]
      end
    end
  end
end
