require File.dirname(__FILE__) + "/../../spec_helper"

describe Munger::Render::Pdf do 
  include MungerSpecHelper
  
  before(:each) do 
    @data = Munger::Data.new(:data => test_data)
    @report = Munger::Report.new(:data => @data)
  end
  
  it "should render a basic pdf with table" do
    @render = Munger::Render::Pdf.new(@report.process)
    pdf = @render.render
    pdf.render_file "test.pdf"
    `open test.pdf`
  end
  
  it "should render pdf with group headers" do
    @report = @report.subgroup(:age, :with_headers => true).sort(:age).process
    @render = Munger::Render::Pdf.new(@report)
    pdf = @render.render
    pdf.render_file "test_with_group_headers.pdf"
    `open test_with_group_headers.pdf`
  end
  
  it "should render pdf pivot" do
    @data.pivot(:day, :name, :score, :sum)
    @report = Munger::Report.new(:data => @data)
    @render = Munger::Render::Pdf.new(@report.process)
    pdf = @render.render
    pdf.render_file "test_with_pivot.pdf"
    `open test_with_pivot.pdf`
  end
end