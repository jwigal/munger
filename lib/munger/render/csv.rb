module Munger #:nodoc:
  module Render #:nodoc:
    class CSV #:nodoc:
    
      attr_reader :report
      
      def csv_class
        if defined?(::CSV)
          ::CSV
        elsif defined?(::FasterCSV)
          ::FasterCSV
        else
          raise NoMethodError, "Could not find a csv parser"
        end
      end
      
      def initialize(report)
        @report = report
      end
      
      def render
        csv_class.generate do |output|
          # header
          output << @report.columns.collect { |col| @report.column_title(col).to_s }        
          # body
          @report.process_data.each do |row|
            output << @report.columns.collect { |col| row[:data][col].to_s }
          end
        end        
      end
      
      def valid?
        @report.is_a? Munger::Report
      end
    
    end
  end
end