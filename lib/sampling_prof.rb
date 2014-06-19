if RUBY_PLATFORM =~ /java/
  require 'sampling_prof.jar'
  require 'sampling_profiler'
else
  require 'sampling_prof/internal'
end

class SamplingProf
  DEFAULT_OUTPUT_FILE = 'profile.txt'

  attr_writer :output_file

  # options:
  #   sampling_interval: default to 0.1 second
  #   &output_handler: default to write into output_file
  def initialize(sampling_interval=0.1, &output_handler)
    @profiler = SamplingProfiler.new(sampling_interval)
    @output_handler = block_given? ? output_handler : default_output_handler
  end

  def start(handler=nil)
    @profiler.start(handler || @output_handler)
  end

  def stop
    @profiler.stop
  end

  def profiling?
    @profiler.profiling?
  end

  def sampling_interval
    @profiler.sampling_interval
  end

  def terminate
    @profiler.terminate
  end

  def output_file
    @output_file ||= DEFAULT_OUTPUT_FILE
  end

  def profile(handler=nil, &block)
    start(handler)
    yield
  ensure
    stop
  end

  def default_output_handler
    lambda do |data|
      File.open(output_file, 'w') do |f|
        f.write(data)
      end
    end
  end

  def report(type, output=$stdout)
    runtime, nodes, counts, call_graph = File.read(output_file).split("\n\n")
    nodes = nodes.split("\n").inject({}) do |ret, l|
      n, i = l.split(',')
      ret[i.to_i] = n
      ret
    end

    counts = counts.split("\n").map do |l|
      l.split(',').map(&:to_i)
    end
    total_samples, report = flat_report(nodes, counts)

    output.puts "runtime: #{runtime.to_f/1000} secs"
    output.puts "total samples: #{total_samples}"
    output.puts "self\t%\ttotal\t%\tname"
    report.first(20).each do |v|
      output.puts v.join("\t")
    end
  end

  def flat_report(nodes, counts)
    total = counts.map{|_,sc,tc| sc}.reduce(:+)
    reports = counts.reject{|_,sc,tc| sc == 0}.sort_by{|_,sc,tc| -sc}.map do |id, sc, tc|
      [sc, '%.2f%' % (100 * sc.to_f/total),
       tc, '%.2f%' % (100 * tc.to_f/total),
       nodes[id]]
    end
    [total, reports]
  end

end
