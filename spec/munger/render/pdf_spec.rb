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
  
end