if RUBY_PLATFORM =~ /java/
  require 'sampling_prof.jar'
else
  require 'sampling_prof/internal'
end

class SamplingProf
  DEFAULT_OUTPUT_FILE = 'profile.txt'

  attr_writer :output_file

  def initialize(sampling_interval=0.1,
                 multithreading=false,
                 output_interval=nil, #sec
                 &output_handler)
    self.sampling_interval = sampling_interval
    self.multithreading = multithreading
    self.output_interval = output_interval || (multithreading ? 60 : nil)
    self.output_handler = block_given? ? output_handler : default_output_handler
    internal_initialize if respond_to?(:internal_initialize)
  end

  def output_file
    @output_file ||= DEFAULT_OUTPUT_FILE
  end

  def profile(&block)
    start
    yield if block_given?
  ensure
    stop if block_given?
  end

  def default_output_handler
    lambda do |data|
      File.open(output_file, 'w') do |f|
        f.write(data)
      end
    end
  end

  def report(type, output=$stdout)
    nodes, counts, call_graph = File.read(output_file).split("\n\n")
    nodes = nodes.split("\n").inject({}) do |ret, l|
      n, i = l.split(',')
      ret[i.to_i] = n
      ret
    end

    counts = counts.split("\n").map do |l|
      l.split(',').map(&:to_i)
    end
    total_samples, report = flat_report(nodes, counts)

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
