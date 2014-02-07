require 'test_helper'

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
  end

  def test_profile_and_output_text_result
    FileUtils.rm_rf(SamplingProf::DEFAULT_OUTPUT_FILE)
    @prof.profile do
      fib(25)
    end
    assert File.exists?(SamplingProf::DEFAULT_OUTPUT_FILE)
  end

  def test_flat_report
    total, report = @prof.flat_report({0 => 'a', 1 => 'b'},
                                      [[0, 1], [1, 4]])

    assert_equal 5, total
    assert_equal [[4, "80.00%", "b"], [1, "20.00%", "a"]], report
  end

  def test_flat_report_output
    @prof.profile do
      fib(25)
    end
    @prof.report(:flat)
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
