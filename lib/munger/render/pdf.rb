begin
  require 'prawn'
rescue LoadError
  require 'rubygems'
  require 'prawn'
end

module Munger #:nodoc:
  module Render #:nodoc:
    class Pdf
    
      attr_reader :report, :classes, :group_style, :group_font, :table_format, :document_options
      attr_reader :pdf
      def pdf
        @pdf ||= Prawn::Document.new(@document_options)
      end
      
      def initialize(report, options = {})
        @report = report
        set_group_style(options[:group_style])
        set_group_font(options[:group_font])
        set_table_format(options[:table_format])
        set_document_options(options[:document])        
        self
      end

      def set_document_options(options=nil)
        options = {} if !options
        default = {:page_layout => :landscape, :margin => [50,50]}
        @document_options = default.merge(options)        
      end

      
      def set_table_format(options=nil)
        options = {} if !options
        default = {:header => true, :row_colors => %w(ffffff ede5b2), :cell_style => {:border_width => 0} }
        @table_format = default.merge(options)        
      end
      
      def set_group_style(options = nil)
        options = {} if !options
        default = {:style => :bold}
        @group_style = default.merge(options)        
      end

      def set_group_font(options = nil)
        options = {} if !options
        default = {:size => 16}
        @group_font = default.merge(options)        
      end
      
      def render
        if @report.process_data.any?{|row| row[:meta][:group_header]}
          header = @report.columns.collect{|column| @report.column_title(column)}
          table_data = [header]
          @report.process_data.each do |row|
            if row[:meta][:group_header]              
              draw_table( table_data ) if table_data.size > 1
              conditional_page_break
              pdf.font("Helvetica", @group_font) { 
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
      
      def draw_table(data)
        pdf.table(data, @table_format) do
          row(0).borders = [:bottom]
          row(0).border_width = 2
          row(0).font_style = :bold
        end    
        pdf.move_down 20    
      end
      
      def conditional_page_break
        pdf.start_new_page if (pdf.bounds.bottom - pdf.cursor).abs < 50
      end
      
      def pdf_header
        pdf.stroke { pdf.line [ pdf.bounds.left, pdf.bounds.top + 8], [pdf.bounds.right, pdf.bounds.top + 8]}
        pdf.bounding_box [ pdf.bounds.left, pdf.bounds.top + 20], :width => pdf.bounds.width do
          pdf.text "This is the report header."
        end        
      end
      
      def pdf_footer
        pdf.stroke { pdf.line [ pdf.bounds.left, pdf.bounds.bottom + 20], [pdf.bounds.right, pdf.bounds.bottom + 20]}
        pdf.bounding_box [ pdf.bounds.left, pdf.bounds.bottom + 15], :width => pdf.bounds.width do
          pdf.text "This is the report footer. #{pdf.bounds.bottom_right}"
        end        
      end
      
      def pdf_page_numbers
        pdf.draw_text pdf.page_number, :at => [pdf.bounds.right - 5, 0]
      end
    end
  end
end
