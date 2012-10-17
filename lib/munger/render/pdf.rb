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
      :table_format => {:header => true, :row_colors => %w(ffffff ede5b2), :cell_style => {:border_width => 0},
      :font_size => 10, :font_face => "Helvetica", 
      :header_style => {:background_color => '617494', :text_color => 'ffffff'} },
      :document => {:page_layout => :landscape, :margin => [50,50]},
      :header => {:size => 12, :font => "Helvetica", :text => "the header"},
      :footer => {:size => 12, :font => "Helvetica", :text => "the footer"}
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
          render_group_tables
        else
          render_single_table
        end
        
        pdf.repeat(:all, :dynamic => true) do 
          pdf_header
          pdf_footer
        end
        pdf 
      end
      
      def valid?
        @report.is_a? Munger::Report
      end
      
      protected

      def page_width
        @page_width ||= (pdf.bounds.left - pdf.bounds.right).abs
      end
      
      def render_grand_total(row)
        pdf.move_down 20    
        row[:aggregate].each do |field,hash|
          hash.each do |aggregate,v|
            if aggregate.is_a?(Proc)
              pdf.text "#{@report.column_title(field.to_sym)}: #{v}"
            else
              pdf.text "Total #{aggregate.to_s.capitalize} of #{@report.column_title(field.to_sym)}: #{v}"
            end
          end
        end               
      end
      
      def render_subtotals(row, group_name)
        if row[:aggregate].respond_to?(:each)
          row[:aggregate].each do |field,hash|
            hash.each do |aggregate,v|
              if aggregate.is_a?(Proc)
                pdf.text "#{@report.column_title(field.to_sym)}: #{v}"
              else
                pdf.text "#{aggregate.to_s.capitalize} of #{@report.column_title(field.to_sym)} for #{group_name}: #{v}"
              end
            end
          end   
        end            
        pdf.move_down 10    
      end
      
      def page_break_after_each_group?
        @report.subgroup_options && (@report.subgroup_options[:with_headers] == :page_break)
      rescue NoMethodError
        false
      end
      
      def render_group_tables
        header = @report.columns.collect{|column| @report.column_title(column)}
        table_data = [header]
        group_name = nil
        @report.process_data.each do |row|
          if row[:meta][:group_header]              
            draw_table( table_data ) if table_data.size > 1
            conditional_page_break
            group_name = row[:meta][:group_value].to_s
            pdf.font(@group_font_face, @group_font) do  
              pdf.text group_name, @group_style 
            end
            table_data = [header]
          elsif row[:meta][:data] 
            table_data << @report.columns.collect do |column|
              row[:data][column].to_s
            end 
          elsif row[:meta][:group] == 0
            render_grand_total(row)
          elsif row[:meta][:group] == 1
            draw_table( table_data ) if table_data.size > 1
            pdf.move_down 5
            render_subtotals(row,group_name)            
            table_data = [header]
            pdf.start_new_page if page_break_after_each_group?
          end
        end 
        draw_table(table_data) if table_data.size > 1         
      end
      
      def render_single_table
        table_data = [@report.columns.collect{|column| @report.column_title(column)}]
        summary_row = nil
        @report.process_data.each do |row|
          if row[:meta][:data] 
            table_data << @report.columns.collect do |column|
              row[:data][column].to_s
            end 
          elsif row[:meta][:group] == 0
            summary_row = row
          end
        end
        draw_table table_data 
        render_grand_total(summary_row) if summary_row
      end

      def set_header_options(options = nil)
        options = {} if !options
        default = {:size => 12, :font => "Helvetica"}
        @header_font = default.merge(options)        
        @header_font_face = @header_font.delete(:font)
        @header_text = @header_font.delete(:text)
      end

      def set_footer_options(options = nil)
        options = {} if !options
        default = {:size => 12, :font => "Helvetica"}
        @footer_font = default.merge(options)        
        @footer_font_face = @footer_font.delete(:font)
        @footer_text = @footer_font.delete(:text)
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
          :font_size => 10, :font_face => "Helvetica", :header_style => {}
        }
        options = default.merge(options)
        @table_header_style = options.delete(:header_style)
        @table_font_size = options.delete(:font_size)        
        @table_font_face = options.delete(:font_face)        
        @table_format = options
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
        ths = @table_header_style        
        pdf.font(@table_font_face, :size => @table_font_size) do
          pdf.table(data, @table_format) do
            # row(0).borders = [:bottom]
            # row(0).border_width = 2
            row(0).font_style = :bold
            row(0).style(ths) unless (ths.nil? || ths == {})
          end
        end
      end
      
      def conditional_page_break
        pdf.start_new_page if (pdf.bounds.bottom - pdf.cursor).abs < 50
      end
      
      def pdf_header
        pdf.stroke { pdf.line [ pdf.bounds.left, pdf.bounds.top + 8], [pdf.bounds.right, pdf.bounds.top + 8]}
        return unless @header_text
        left_side = @header_text.respond_to?(:pop) ? @header_text[0] : @header_text
        right_side = @header_text.respond_to?(:pop) ? @header_text[1] : "Page #{pdf.page_number} of #{pdf.page_count}"
        pdf.font(@header_font_face, @header_font) do
          pdf.bounding_box([ pdf.bounds.left, pdf.bounds.top + 20], :width => page_width) do
            pdf.text left_side, :align => :left
          end
          pdf.bounding_box([ pdf.bounds.left, pdf.bounds.top + 20], :width => page_width) do
            pdf.text right_side, :align => :right
          end
        end
      end
      
      def pdf_footer
        pdf.stroke { pdf.line [ pdf.bounds.left, pdf.bounds.bottom], [pdf.bounds.right, pdf.bounds.bottom ]}
        left_side = @footer_text.respond_to?(:pop) ? @footer_text[0] : @footer_text
        right_side = @footer_text.respond_to?(:pop) ? @footer_text[1] : "Page #{pdf.page_number} of #{pdf.page_count}"
        pdf.font(@footer_font_face, @footer_font) do
          pdf.text_box right_side, :at => [0, -2], :width => page_width, :align => :right, 
            :single_line => true, :height => 12

          pdf.text_box left_side, :at => [0, -2], :width => page_width, :align => :left, 
            :single_line => true, :height => 12

        end
      end
      
    end
  end
end
