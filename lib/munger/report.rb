module Munger #:nodoc:
  
  class Report
    
    attr_writer :data, :sort, :columns, :subgroup, :aggregate
    attr_accessor :column_titles, :column_data_fields, :column_formatters, :subgroup_options
    attr_reader :process_data, :grouping_level
    
    # r = Munger::Report.new ( :data => data, 
    #   :columns => [:collect_date, :spot_name, :airings, :display_name],
    #   :sort => [:collect_date, :spot_name]
    #   :subgroup => @group_list,
    #   :aggregate => {:sum => new_columns} )
    # report = r.highlight
    def initialize(options = {})
      @grouping_level = 0
      @column_titles = {}
      @column_data_fields = {}
      @column_formatters = {}
      set_options(options)
    end
    
    def self.from_data(data)
      Report.new(:data => data)
    end
    
    def set_options(options)
      if d = options[:data]
        if d.is_a? Munger::Data
          @data = d
        else
          @data = Munger::Data.new(:data => d)
        end
      end
      self.sort(options[:sort]) if options[:sort]
      self.columns(options[:columns]) if options[:columns]
      self.subgroup(options[:subgroup]) if options[:subgroup]
      self.aggregate(options[:aggregate]) if options[:aggregate]
    end
    
    def processed?
      if @process_data
        true
      else
        false
      end
    end
    
    # returns ReportTable
    def process(options = {})
      set_options(options)
            
      # sorts and fills NativeReport 
      @report = translate_native(do_field_sort(@data.data))
      
      do_add_groupings
      do_add_aggregate_rows
      
      self
    end
    
    def sort(values = nil)
      if values
        @sort = values 
        self
      else
        @sort
      end
    end
    
    def subgroup(values = nil, options = {})
      if values
        @subgroup = values 
        @subgroup_options = options
        self
      else
        @subgroup
      end
    end
    
    def columns(values = nil)
      if values
        if values.is_a? Hash
          @columns = values.keys
          @column_titles = values
        else
          @columns = Data.array(values)
        end
        self
      else
        @columns ||= @data.columns
      end
    end

    def column_title(column)
      if c = @column_titles[column]
        return c.to_s
      else
        return column.to_s
      end
    end
    
    def column_data_field(column)
      @column_data_fields[column] || column.to_s
    end
    
    def column_formatter(column)
      @column_formatters[column]
    end
    
    def aggregate(values = nil)
      if values
        @aggregate = values 
        self
      else
        @aggregate
      end
    end
    
    def rows
      @process_data.size
    end
    
    def valid?
      (@data.is_a? Munger::Data) && (@data.valid?)
    end

    # @report.style_cells('highlight') { |cell, row| cell > 32 }
    def style_cells(style, options = {})
      @process_data.each_with_index do |row, index|
        
        # filter columns to look at
        if options[:only]
          cols = Data.array(options[:only])
        elsif options [:except]
          cols = columns - Data.array(options[:except])
        else
          cols = columns
        end

        if options[:no_groups] && row[:meta][:group]
          next
        end
          
        cols.each do |col|
          if yield(row[:data][col], row[:data])
            @process_data[index][:meta][:cell_styles] ||= {}
            @process_data[index][:meta][:cell_styles][col] ||= []
            @process_data[index][:meta][:cell_styles][col] << style
          end
        end
      end
    end
    
    # @report.style_rows('highlight') { |row| row.age > 32 }
    def style_rows(style, options = {})
      @process_data.each_with_index do |row, index|
        if yield(row[:data])
          @process_data[index][:meta][:row_styles] ||= []
          @process_data[index][:meta][:row_styles] << style
        end
      end
    end

    # post-processing calls

    def get_subgroup_rows(group_level = nil)
      data = @process_data.select { |r| r[:meta][:group] }
      data = data.select { |r| r[:meta][:group] == group_level } if group_level
      data
    end
    
    def to_s
      pp @process_data
    end
    
    private 
      
      def translate_native(array_of_hashes)
        @process_data = []
        array_of_hashes.each do |row|
          @process_data << {:data => Item.ensure(row), :meta => {:data => true}}
        end
      end
      
      def do_add_aggregate_rows
        return false if !@aggregate
        return false if !@aggregate.is_a? Hash
        return false if @process_data.size == 0
        totals = {}        
        
        @process_data.each_with_index do |row, index|
          if row[:meta][:data]
            @aggregate.each do |type, columns|
              Data.array(columns).each do |column|
                value = row[:data][column]
                @grouping_level.downto(0) do |level|
                  totals[column] ||= {}
                  totals[column][level] ||= []
                  totals[column][level] << value
                end
              end
            end
          elsif level = row[:meta][:group] 
            # write the totals and reset level
            @aggregate.each do |type, columns|
              Data.array(columns).each do |column|
                data = totals[column][level]
                @process_data[index][:data][column] = calculate_aggregate(type, data)
                if type.is_a?(Symbol)
                  @process_data[index][:aggregate] ||= {}
                  @process_data[index][:aggregate][column] ||= {}
                  @process_data[index][:aggregate][column][type] = @process_data[index][:data][column]
                end
                totals[column][level] = []
              end
            end
          end
        end
              
        total_row = {:data => {}, :meta => {:group => 0}, :aggregate => {}}
        # write one row at the end with the totals
        @aggregate.each do |type, columns|
          Data.array(columns).each do |column|
            data = totals[column][0]
            total_row[:data][column] = calculate_aggregate(type, data)
            total_row[:aggregate][column] ||= {}
            total_row[:aggregate][column][type] = total_row[:data][column]
          end
        end
        @process_data << total_row
        
      end
      
      def calculate_aggregate(type, data)
        return 0 if !data
        if type.is_a? Proc
          type.call(data)
        else
          case type
          when :count
            data.size
          when :average
            sum = data.inject {|sum, n| sum + n }
            (sum / data.size) rescue 0
          else
            data.inject {|sum, n| sum + n }
          end
        end
      end
      
      def do_add_groupings
        return false if !@subgroup
        return false if @process_data.size == 0
        sub = Data.array(@subgroup)
        @grouping_level = sub.size
        
        current = {}
        new_data = []
        
        first_row = @process_data.first
        sub.reverse.each do |group|
          current[group] = first_row[:data][group]
        end
        prev_row = {:data => {}}
        
        @process_data.each_with_index do |row, index|
          # insert header title rows
          next_row = @process_data[index + 1]
          
          if next_row
            
            # insert header rows
            if @subgroup_options[:with_headers]
              level = 1
              sub.each do |group|
                if (prev_row[:data][group] != current[group]) && current[group]
                  group_row = {:data => {}, :meta => {:group_header => level, 
                              :group_name => group, :group_value => row[:data][group]}}
                  new_data << group_row
                end
                level += 1
              end
            end
            
            # insert current row
            new_data << row


            # insert footer rows
            level = @grouping_level
            sub.reverse.each do |group|
              if (next_row[:data][group] != current[group]) && current[group]
                group_row = {:data => {}, :meta => {:group => level, :group_name => group}}
                new_data << group_row
              end
              current[group] = next_row[:data][group]
              level -= 1
            end 
            
            prev_row = row
            
          else  # last row
            level = @grouping_level
            
            # insert header rows
            sub.each do |group|
              if (prev_row[:data][group] != current[group]) && current[group]
                group_row = {:data => {}, :meta => {:group_header => level, 
                            :group_name => group, :group_value => row[:data][group]}}
                new_data << group_row
              end
            end
            
            new_data << row
            
            sub.reverse.each do |group|
              group_row = {:data => {}, :meta => {:group => level, :group_name => group}}
              new_data << group_row
              level -= 1
            end
          end
        end

        @process_data = new_data
      end
      
      def do_field_sort(data)
        data.sort do |a, b|
          compare = 0
          a = Item.ensure(a)
          b = Item.ensure(b)
      
          Data.array(@sort).each do |sorting|
            if sorting.is_a?(String) || sorting.is_a?(Symbol)
              compare = a[sorting.to_s] <=> b[sorting.to_s] rescue 0
              break if compare != 0
            elsif sorting.is_a? Array
              key = sorting[0]
              func = sorting[1]
              if func == :asc
                compare = a[key] <=> b[key]
              elsif func == :desc
                compare = b[key] <=> a[key]
              elsif func.is_a? Proc
                compare = func.call(a[key], b[key])
              end
              break if compare != 0
            end
          end
          compare
        end
      end
    
  end
  
end
