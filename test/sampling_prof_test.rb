require 'test_helper'
require 'stringio'
require 'fileutils'

class SamplingProfTest < Test::Unit::TestCase
  def setup
    @prof = SamplingProf.new(0.01)
  end

  def test_start_profile
    assert !@prof.profiling?
    assert !@prof.stop

    assert @prof.start

    assert !@prof.start
    assert @prof.profiling?

    assert @prof.stop

    assert !@prof.stop
    assert !@prof.profiling?
  ensure
    FileUtils.rm_rf @prof.output_file
  end

  def test_profile_and_output_text_result
    FileUtils.rm_rf(SamplingProf::DEFAULT_OUTPUT_FILE)
    @prof.profile do
      fib(25)
    end
    assert File.exists?(SamplingProf::DEFAULT_OUTPUT_FILE)
  ensure
    FileUtils.rm_rf @prof.output_file
  end

  def test_flat_report
    total, report = @prof.flat_report({0 => 'a', 1 => 'b'},
                                      [[0, 1], [1, 4]])

    assert_equal 5, total
    assert_equal [[4, "80.00%", "b"], [1, "20.00%", "a"]], report
  end

  def test_flat_report_output
    output = <<-TXT
total counts: 12
calls	%	name
8	66.67%	test/sampling_prof_test.rb:69:fib
2	16.67%	test/sampling_prof_test.rb:64:fib
2	16.67%	test/sampling_prof_test.rb:69:+
TXT
    @prof.output_file = File.dirname(__FILE__) + '/profile.txt'
    result = StringIO.open do |io|
      @prof.report(:flat, io)
      io.string
    end
    assert_equal output, result
  end

  def fib(i)
    if i == 1
      0
    elsif i == 2
      1
    else
      fib(i - 1) + fib(i - 2)
    end
  end
end
