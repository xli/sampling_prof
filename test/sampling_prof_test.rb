require 'test_helper'
require 'stringio'
require 'fileutils'

class SamplingProfTest < Test::Unit::TestCase
  def setup
    @prof = SamplingProf.new(0.01)
  end

  def test_accept_default_callback_while_initializing
    @data = []
    @prof = SamplingProf.new(0.01) do |data|
      @data << data
    end
    @prof.profile do
      fib(5)
    end
    assert @data.size > 0
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

  def test_start_profile_with_specific_output_handler
    @data = nil
    @prof = SamplingProf.new(0.01) do |data|
      @data = data
    end
    @prof.profile { fib(10) }
    assert @data
    assert !File.exist?(SamplingProf::DEFAULT_OUTPUT_FILE)
  end

  def test_profile_and_output_text_result
    FileUtils.rm_rf(SamplingProf::DEFAULT_OUTPUT_FILE)
    @prof.profile do
      fib(35)
    end
    assert File.exist?(SamplingProf::DEFAULT_OUTPUT_FILE)
    runtime, nodes, counts, call_graph = File.read(SamplingProf::DEFAULT_OUTPUT_FILE).split("\n\n")

    assert runtime.to_f > 100 # unit is ms
    assert nodes.split("\n").size > 1
    assert counts.split("\n").size > 1
    assert call_graph.split("\n").size > 1
  ensure
    FileUtils.rm_rf @prof.output_file
  end

  def test_default_options
    @prof = SamplingProf.new
    assert_equal 0.1, @prof.sampling_interval
    assert_equal false, @prof.multithreading
    assert_equal nil, @prof.output_interval

    @prof = SamplingProf.new(0.1, true)
    assert_equal 0.1, @prof.sampling_interval
    assert_equal true, @prof.multithreading
    assert_equal 60, @prof.output_interval
  end

  def test_change_default_output_interval_to_nil
    @prof = SamplingProf.new(0.1, true, nil)
    assert_nil @prof.output_interval

    @prof = SamplingProf.new(0.1, true)
    @prof.output_interval = nil
    assert_nil @prof.output_interval
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
    sampling = SamplingProf::Sampling.new([thread])
    sampling.process
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
    assert runtime.to_f > 0
    assert_equal expected, [nodes, counts, call_graph].join("\n\n")
  end
end
