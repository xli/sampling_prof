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
    assert File.exist?(SamplingProf::DEFAULT_OUTPUT_FILE)
  ensure
    FileUtils.rm_rf @prof.output_file
  end

  def test_flat_report
    total, report = @prof.flat_report({0 => 'a', 1 => 'b'},
                                      [[0, 1, 5], [1, 4, 4]])

    assert_equal 5, total
    expected = [[4, "80.00%", 4, "80.00%", "b"],
                [1, "20.00%", 5, "100.00%", "a"]]
    assert_equal expected, report
  end

  def test_flat_report_output
    output = <<-TXT
total samples: 15
self	%	total	%	name
6	40.00%	15	100.00%	test/sampling_prof_test.rb:73:fib
3	20.00%	3	20.00%	test/sampling_prof_test.rb:69:fib
3	20.00%	4	26.67%	test/sampling_prof_test.rb:68:fib
2	13.33%	2	13.33%	test/sampling_prof_test.rb:73:-
1	6.67%	1	6.67%	test/sampling_prof_test.rb:68:==
TXT
    @prof.output_file = File.dirname(__FILE__) + '/profile.txt'
    result = StringIO.open do |io|
      @prof.report(:flat, io)
      io.string
    end

    assert_equal output, result
  end

  def test_snapshot
    unless defined?(SamplingProf::Sampling)
      print "S"
      return
    end
    sampling = SamplingProf::Sampling.new
    sampling.process([OpenStruct.new(:path => 'path1', :label => 'm1', :lineno => 1),
                       OpenStruct.new(:path => 'path2', :label => 'm2', :lineno => 2),
                       OpenStruct.new(:path => 'path3', :label => 'm3', :lineno => 3)])
    nodes, samples, call_graph = sampling.result
    assert_equal [['path3:3:m3', 0], ['path2:2:m2', 1], ['path1:1:m1', 2]], nodes
    assert_equal [[0, [0, 1]], [1, [0, 1]], [2, [1, 1]]], samples
    assert_equal [[[-1, 0], 1], [[0, 1], 1], [[1, 2], 1]], call_graph
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
