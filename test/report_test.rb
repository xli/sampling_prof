require 'test_helper'
require 'stringio'

class ReportTest < Test::Unit::TestCase
  def setup
    @prof = SamplingProf.new(0.01)
  end

  def teardown
    @prof.terminate if @prof
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
    @prof.output_file = File.dirname(__FILE__) + '/profile.txt'
    result = StringIO.open do |io|
      @prof.report(:flat, io)
      io.string
    end

    expected_output = <<-TXT
runtime: 1.567 secs
total samples: 15
self	%	total	%	name
6	40.00%	15	100.00%	test/sampling_prof_test.rb:73:fib
3	20.00%	3	20.00%	test/sampling_prof_test.rb:69:fib
3	20.00%	4	26.67%	test/sampling_prof_test.rb:68:fib
2	13.33%	2	13.33%	test/sampling_prof_test.rb:73:-
1	6.67%	1	6.67%	test/sampling_prof_test.rb:68:==
TXT
    assert_equal expected_output, result
  end

  def test_snapshot
    unless defined?(SamplingProf::Sampling)
      print "S"
      return
    end
    thread = OpenStruct.new(:backtrace_locations => [OpenStruct.new(:path => 'path1', :label => 'm1', :lineno => 1),
                                                     OpenStruct.new(:path => 'path2', :label => 'm2', :lineno => 2),
                                                     OpenStruct.new(:path => 'path3', :label => 'm3', :lineno => 3)])
    sampling = SamplingProf::Sampling.new(lambda {})
    sleep 0.1
    sampling.process(thread)
    data = sampling.result
    runtime, nodes, counts, call_graph = data.split("\n\n")
    expected = <<-DATA
path3:3:m3,0
path2:2:m2,1
path1:1:m1,2

0,0,1
1,0,1
2,1,1

-1,0,1
0,1,1
1,2,1
DATA
    assert runtime.to_i > 10
    assert_equal expected, [nodes, counts, call_graph].join("\n\n")
  end
end
