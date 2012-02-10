begin
  require 'prawn'
rescue LoadError
  require 'rubygems'
  require 'prawn'
end

module Munger #:nodoc:
  module Render #:nodoc:
    class Pdf
    
      attr_reader :report, :classes
      
      def initialize(report, options = {})
        @report = report
        set_classes(options[:classes])
      end
      
      def set_classes(options = nil)
        options = {} if !options
        default = {:table => 'report-table'}
        @classes = default.merge(options)
      end
      
      def render
        pdf = Prawn::Document.new
        table_data = []
        if @report.process_data.any?{|row| row[:meta][:group_header]}
        
        else
          table_data << @report.columns.collect{|column| @report.column_title(column)}
          @report.process_data.each do |row|
            table_data << @report.columns.collect do |column|
              row[:data][column].to_s
            end 
          end 
        end
        pdf.table(table_data)
        pdf 
      end
      
      def cycle(one, two)
        if @current == one
          @current = two
        else
          @current = one
        end
      end
      
      def valid?
        @report.is_a? Munger::Report
      end
    
    end
  end
end
